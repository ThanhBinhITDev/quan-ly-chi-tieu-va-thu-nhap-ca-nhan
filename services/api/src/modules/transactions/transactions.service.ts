import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type {
  CreateTransactionDto,
  ListTransactionsQuery,
  UpdateTransactionDto,
} from './transaction.dto.js';

export interface TransactionRow {
  id: string;
  wallet_id: string;
  category_id: string | null;
  type: string;
  amount: string | number;
  to_wallet_id: string | null;
  note: string | null;
  occurred_at: Date | string;
  occurred_on: string;
  source: string;
  rev: number;
  created_at: Date | string;
  updated_at: Date | string;
  deleted_at: Date | string | null;
}

const SELECT_COLUMNS = `id, wallet_id, category_id, type, amount, to_wallet_id,
       note, occurred_at, occurred_on, source, rev, created_at, updated_at, deleted_at`;

@Injectable()
export class TransactionsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /**
   * Danh sách theo cursor `occurred_at` giảm dần.
   * `occurred_on` do trigger DB sinh theo giờ Việt Nam, client không gửi.
   */
  async list(
    userId: string,
    query: ListTransactionsQuery,
  ): Promise<TransactionRow[]> {
    const limit = query.limit ?? 50;
    const params: unknown[] = [userId];
    const filters = ['user_id = $1'];

    if (!query.include_deleted) {
      filters.push('deleted_at IS NULL');
    }
    if (query.type) {
      params.push(query.type);
      filters.push(`type = $${params.length}`);
    }
    if (query.before) {
      params.push(query.before);
      filters.push(`occurred_at < $${params.length}`);
    }
    params.push(limit);

    const rows = await this.db.query<TransactionRow>(
      `SELECT ${SELECT_COLUMNS}
         FROM transactions
        WHERE ${filters.join(' AND ')}
        ORDER BY occurred_at DESC, id DESC
        LIMIT $${params.length}`,
      params,
    );
    return rows.map(toTransaction);
  }

  async create(
    userId: string,
    dto: CreateTransactionDto,
  ): Promise<TransactionRow> {
    if (dto.type === 'transfer' && !dto.to_wallet_id) {
      throw new ApiError(
        'RULE_VIOLATION',
        'Chuyển ví phải có ví nhận',
        { field: 'to_wallet_id' },
      );
    }
    if (dto.type === 'transfer' && dto.to_wallet_id === dto.wallet_id) {
      throw new ApiError('RULE_VIOLATION', 'Ví nhận phải khác ví gửi', {
        field: 'to_wallet_id',
      });
    }
    if (dto.category_id) {
      const category = await this.db.one<{ id: string }>(
        `SELECT id FROM categories
          WHERE id = $1 AND (user_id IS NULL OR user_id = $2) AND deleted_at IS NULL`,
        [dto.category_id, userId],
      );
      if (!category) {
        throw new ApiError('NOT_FOUND', 'Danh mục không tồn tại', {
          field: 'category_id',
        });
      }
    }

    // Client sinh id: gửi lại cùng id phải idempotent, không tạo bản ghi trùng.
    const existing = await this.db.one<{ id: string; user_id: string }>(
      `SELECT id, user_id FROM transactions WHERE id = $1`,
      [dto.id],
    );
    if (existing) {
      if (existing.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Giao dịch thuộc người dùng khác');
      }
      const row = await this.findById(userId, dto.id);
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch');
      return row;
    }

    await this.assertWallet(userId, dto.wallet_id, 'wallet_id');
    if (dto.to_wallet_id) {
      await this.assertWallet(userId, dto.to_wallet_id, 'to_wallet_id');
    }

    const row = await this.db.one<TransactionRow>(
      `INSERT INTO transactions
         (id, user_id, wallet_id, category_id, type, amount, to_wallet_id,
          note, occurred_at, source)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING ${SELECT_COLUMNS}`,
      [
        dto.id,
        userId,
        dto.wallet_id,
        dto.category_id ?? null,
        dto.type,
        dto.amount,
        dto.to_wallet_id ?? null,
        dto.note ?? null,
        dto.occurred_at,
        dto.source ?? 'manual',
      ],
    );
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được giao dịch');
    return toTransaction(row);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateTransactionDto,
  ): Promise<TransactionRow> {
    const current = await this.findById(userId, id, true);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch');
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }
    if (dto.category_id) {
      const category = await this.db.one<{ id: string }>(
        `SELECT id FROM categories
          WHERE id = $1 AND (user_id IS NULL OR user_id = $2) AND deleted_at IS NULL`,
        [dto.category_id, userId],
      );
      if (!category) {
        throw new ApiError('NOT_FOUND', 'Danh mục không tồn tại', {
          field: 'category_id',
        });
      }
    }

    const row = await this.db.one<TransactionRow>(
      `UPDATE transactions
          SET amount = COALESCE($3, amount),
              category_id = COALESCE($4, category_id),
              note = COALESCE($5, note),
              occurred_at = COALESCE($6, occurred_at),
              deleted_at = COALESCE($7, deleted_at),
              rev = rev + 1
        WHERE id = $1 AND user_id = $2
        RETURNING ${SELECT_COLUMNS}`,
      [
        id,
        userId,
        dto.amount ?? null,
        dto.category_id ?? null,
        dto.note ?? null,
        dto.occurred_at ?? null,
        dto.deleted_at ?? null,
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch');
    return toTransaction(row);
  }

  private async assertWallet(
    userId: string,
    walletId: string,
    field: string,
  ): Promise<void> {
    const wallet = await this.db.one<{ id: string }>(
      `SELECT id FROM wallets
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [walletId, userId],
    );
    if (!wallet) {
      throw new ApiError('NOT_FOUND', 'Ví không tồn tại', { field });
    }
  }

  private async findById(
    userId: string,
    id: string,
    includeDeleted = false,
  ): Promise<TransactionRow | null> {
    const row = await this.db.one<TransactionRow>(
      `SELECT ${SELECT_COLUMNS}
         FROM transactions
        WHERE id = $1 AND user_id = $2 ${includeDeleted ? '' : 'AND deleted_at IS NULL'}`,
      [id, userId],
    );
    return row ? toTransaction(row) : null;
  }
}

function toTransaction(row: TransactionRow): TransactionRow {
  return {
    ...row,
    amount: Number(row.amount),
    occurred_at: toIso(row.occurred_at),
    created_at: toIso(row.created_at),
    updated_at: toIso(row.updated_at),
    deleted_at: row.deleted_at ? toIso(row.deleted_at) : null,
  };
}

function toIso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}
