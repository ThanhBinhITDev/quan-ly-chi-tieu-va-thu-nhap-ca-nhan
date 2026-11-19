import { Inject, Injectable, Logger } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import type { PullQuery, PushDto, SyncChangeDto } from './sync.dto.js';

export interface SyncApplied {
  table: string;
  id: string;
  status: 'ok';
  rev: number;
}

export interface SyncConflict {
  table: string;
  id: string;
  status: 'conflict';
  server_rev: number;
  server_data: Record<string, unknown>;
}

export interface PushResult {
  applied: SyncApplied[];
  conflicts: SyncConflict[];
  server_time: string;
}

const SYNC_ORDER = ['transactions', 'wallets', 'categories', 'budgets'] as const;

/**
 * Đồng bộ theo hợp đồng mục 10: client đẩy thay đổi, server so `rev`.
 * - rev client = rev server + 1  -> áp dụng
 * - rev client <= rev server     -> conflict kèm dữ liệu server
 * Không xoá cứng: `delete` chỉ set deleted_at.
 */
@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async push(userId: string, dto: PushDto): Promise<PushResult> {
    const applied: SyncApplied[] = [];
    const conflicts: SyncConflict[] = [];

    for (const change of dto.changes) {
      try {
        const outcome = await this.applyChange(userId, change);
        if (outcome.status === 'conflict') {
          conflicts.push(outcome);
        } else {
          applied.push(outcome);
        }
      } catch (error) {
        // Một bản ghi lỗi không được làm hỏng cả lô.
        this.logger.warn(
          `Sync thất bại cho ${change.table}/${change.id}: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
        conflicts.push({
          table: change.table,
          id: change.id,
          status: 'conflict',
          server_rev: 0,
          server_data: {},
        });
      }
    }

    await this.touchDevice(userId, dto.device_id);
    return { applied, conflicts, server_time: new Date().toISOString() };
  }

  async pull(userId: string, query: PullQuery) {
    const limit = Math.min(query.limit ?? 500, 500);
    const changes: Array<{
      table: string;
      op: string;
      id: string;
      rev: number;
      data: Record<string, unknown>;
    }> = [];

    let nextSince = new Date(query.since);
    let hasMore = false;

    for (const table of SYNC_ORDER) {
      if (changes.length >= limit) {
        hasMore = true;
        break;
      }
      const rows = await this.db.query<{
        id: string;
        rev: number;
        updated_at: Date | string;
        deleted_at: Date | string | null;
        payload: Record<string, unknown>;
      }>(
        `SELECT id, rev, updated_at, deleted_at, to_jsonb(t) AS payload
           FROM ${table} t
          WHERE user_id = $1 AND updated_at > $2::timestamptz
          ORDER BY updated_at ASC
          LIMIT $3`,
        [userId, query.since, limit - changes.length],
      );

      for (const row of rows) {
        const updatedAt = new Date(row.updated_at);
        changes.push({
          table,
          op: row.deleted_at ? 'delete' : row.rev === 1 ? 'insert' : 'update',
          id: row.id,
          rev: row.rev,
          data: row.payload,
        });
        if (updatedAt > nextSince) nextSince = updatedAt;
      }
      if (rows.length === limit - changes.length) hasMore = true;
    }

    return {
      changes,
      next_since: nextSince.toISOString(),
      has_more: hasMore,
    };
  }

  private async applyChange(
    userId: string,
    change: SyncChangeDto,
  ): Promise<SyncApplied | SyncConflict> {
    const existing = await this.db.one<{
      rev: number;
      payload: Record<string, unknown>;
    }>(
      `SELECT rev, to_jsonb(t) AS payload
         FROM ${change.table} t
        WHERE id = $1 AND user_id = $2`,
      [change.id, userId],
    );

    // Cột được ghi: chỉ cột an toàn + deleted_at khi xoá.
    const columns = this.editableColumns(change.table).filter(
      (column) => column in change.data,
    );
    if (change.op === 'delete' && !columns.includes('deleted_at')) {
      columns.push('deleted_at');
    }
    const values = columns.map((column) =>
      column === 'deleted_at' && change.op === 'delete'
        ? (change.data.deleted_at ?? new Date().toISOString())
        : change.data[column],
    );

    if (!existing) {
      if (change.op === 'delete') {
        // Xoá bản ghi chưa từng có trên server: coi như xong (idempotent).
        return { table: change.table, id: change.id, status: 'ok', rev: change.rev };
      }
      await this.db.query(
        `INSERT INTO ${change.table} (id, user_id, ${columns.join(', ')})
         VALUES ($1, $2, ${columns.map((_, i) => `$${i + 3}`).join(', ')})`,
        [change.id, userId, ...values],
      );
      return { table: change.table, id: change.id, status: 'ok', rev: change.rev };
    }

    if (change.rev <= existing.rev) {
      return {
        table: change.table,
        id: change.id,
        status: 'conflict',
        server_rev: existing.rev,
        server_data: existing.payload,
      };
    }

    if (columns.length === 0) {
      // Không có gì để ghi nhưng rev hợp lệ: vẫn tăng rev để đồng bộ tiến.
      await this.db.query(
        `UPDATE ${change.table} SET rev = rev + 1
          WHERE id = $1 AND user_id = $2`,
        [change.id, userId],
      );
    } else {
      await this.db.query(
        `UPDATE ${change.table}
            SET ${columns.map((c, i) => `${c} = $${i + 3}`).join(', ')},
                rev = rev + 1
          WHERE id = $1 AND user_id = $2`,
        [change.id, userId, ...values],
      );
    }
    return {
      table: change.table,
      id: change.id,
      status: 'ok',
      rev: existing.rev + 1,
    };
  }

  private editableColumns(table: SyncChangeDto['table']): string[] {
    switch (table) {
      case 'wallets':
        return ['name', 'type', 'initial_balance', 'color', 'icon', 'sort_order'];
      case 'categories':
        return ['name', 'type', 'icon', 'color', 'parent_id', 'sort_order'];
      case 'transactions':
        return [
          'wallet_id',
          'category_id',
          'type',
          'amount',
          'to_wallet_id',
          'note',
          'occurred_at',
          'source',
        ];
      case 'budgets':
        return ['category_id', 'amount', 'period', 'start_date', 'end_date'];
      case 'goals':
        return ['name', 'target_amount', 'saved_amount', 'target_date'];
      case 'recurring_rules':
        return [
          'amount',
          'type',
          'category_id',
          'wallet_id',
          'note',
          'frequency',
          'interval',
          'next_run_at',
        ];
    }
  }

  private async touchDevice(userId: string, deviceId: string): Promise<void> {
    // Thiết bị có thể chưa đăng ký; lỗi ở đây không được làm hỏng sync.
    await this.db
      .query(`UPDATE devices SET last_sync_at = now() WHERE id = $1 AND user_id = $2`, [
        deviceId,
        userId,
      ])
      .catch(() => undefined);
  }
}
