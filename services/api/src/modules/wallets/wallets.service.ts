import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type { CreateWalletDto, UpdateWalletDto } from './wallet.dto.js';

export interface WalletRow {
  id: string;
  name: string;
  type: string;
  initial_balance: string | number;
  /** Số dư hiện tại = initial_balance + thu - chi + chuyển vào - chuyển ra. */
  balance: string | number;
  color: string | null;
  icon: string | null;
  is_archived: boolean;
  rev: number;
  deleted_at?: string | null;
}

/**
 * Số dư không lưu trong bảng (Q1: `transactions` là nguồn sự thật duy nhất).
 * Biểu thức SQL dưới đây phải khớp công thức ở
 * `docs/system-design/01-database-schema.md`:
 *
 *   balance = initial_balance + SUM(income) - SUM(expense)
 *             + SUM(transfer_in) - SUM(transfer_out)
 *
 * Giao dịch đã xoá mềm không được tính.
 */
const BALANCE_EXPR = `(w.initial_balance + COALESCE((
    SELECT SUM(CASE
                 WHEN t.type = 'income' THEN t.amount
                 WHEN t.type = 'expense' THEN -t.amount
                 WHEN t.type = 'transfer' AND t.to_wallet_id = w.id THEN t.amount
                 WHEN t.type = 'transfer' AND t.wallet_id = w.id THEN -t.amount
                 ELSE 0
               END)
      FROM transactions t
     WHERE (t.wallet_id = w.id
            OR (t.type = 'transfer' AND t.to_wallet_id = w.id))
       AND t.deleted_at IS NULL
  ), 0))`;

const COLUMNS = `w.id, w.name, w.type, w.initial_balance,
       ${BALANCE_EXPR} AS balance,
       w.color, w.icon, w.is_archived, w.rev, w.deleted_at`;

/**
 * Tổng hợp số dư theo ví. Cộng dồn từ chính [list] để không lệch công thức
 * với `/v1/wallets` (một nguồn sự thật, không viết lại phép tính lần hai).
 */
export interface WalletBalances {
  wallets: Array<{
    id: string;
    name: string;
    type: string;
    is_archived: boolean;
    balance: number;
  }>;
  /** Tổng số dư tất cả ví đang hoạt động. */
  total_balance: number;
  /** Số dư gộp theo loại ví: cash, bank, ewallet, credit. */
  by_type: Record<string, number>;
  computed_at: string;
}

/** Gói miễn phí: tối đa 3 ví đang hoạt động (hợp đồng API, mục 4.2). */
const FREE_PLAN_ACTIVE_WALLETS = 3;
/** Gói trả phí không giới hạn thực tế; dùng số lớn để giữ câu SQL đơn giản. */
const PAID_PLAN_ACTIVE_WALLETS = 1_000;

@Injectable()
export class WalletsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(userId: string, includeDeleted = false): Promise<WalletRow[]> {
    const rows = await this.db.query<WalletRow>(
      `SELECT ${COLUMNS}
         FROM wallets w
        WHERE w.user_id = $1${includeDeleted ? '' : ' AND w.deleted_at IS NULL'}
        ORDER BY w.sort_order, w.created_at`,
      [userId],
    );
    return rows.map(toWallet);
  }

  async balances(userId: string): Promise<WalletBalances> {
    // `includeDeleted = false`: ví đã xoá không được cộng vào tổng.
    const rows = await this.list(userId);
    const byType: Record<string, number> = {};
    let total = 0;

    const wallets = rows.map((row) => {
      const balance = Number(row.balance);
      total += balance;
      byType[row.type] = (byType[row.type] ?? 0) + balance;
      return {
        id: row.id,
        name: row.name,
        type: row.type,
        is_archived: row.is_archived,
        balance,
      };
    });

    return {
      wallets,
      total_balance: total,
      by_type: byType,
      computed_at: new Date().toISOString(),
    };
  }

  async create(userId: string, dto: CreateWalletDto): Promise<WalletRow> {
    const existing = await this.db.one<{ id: string; user_id: string }>(
      `SELECT id, user_id FROM wallets WHERE id = $1`,
      [dto.id],
    );
    if (existing) {
      // Client sinh id để tạo offline; gửi lại cùng id phải idempotent.
      if (existing.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Ví thuộc người dùng khác');
      }
      const row = await this.findById(userId, dto.id);
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ví');
      return row;
    }

    const active = await this.db.one<{ count: string }>(
      `SELECT count(*)::text AS count
         FROM wallets
        WHERE user_id = $1 AND deleted_at IS NULL AND is_archived = false`,
      [userId],
    );
    // Giới hạn ví phụ thuộc gói. Trước đây dùng hằng 3 cho mọi người, nên
    // người trả tiền cũng bị chặn và gói trả phí không có giá trị gì.
    const limit = await this.activeWalletLimit(userId);
    if (Number(active?.count ?? 0) >= limit) {
      throw new ApiError(
        'PLAN_LIMIT',
        limit === FREE_PLAN_ACTIVE_WALLETS
          ? 'Gói miễn phí chỉ cho phép 3 ví đang hoạt động'
          : `Gói hiện tại chỉ cho phép ${limit} ví đang hoạt động`,
        {
          details: { limit, current: Number(active?.count ?? 0) },
        },
      );
    }

    await this.db.query(
      `INSERT INTO wallets (id, user_id, name, type, initial_balance, color, icon)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        dto.id,
        userId,
        dto.name,
        dto.type,
        dto.initial_balance ?? 0,
        dto.color ?? null,
        dto.icon ?? null,
      ],
    );
    // Ví mới chưa có giao dịch: đọc lại để trả cùng shape (có `balance`).
    const row = await this.findById(userId, dto.id);
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được ví');
    return row;
  }

  async update(
    userId: string,
    walletId: string,
    dto: UpdateWalletDto,
  ): Promise<WalletRow> {
    const current = await this.findById(userId, walletId);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy ví');
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }

    await this.db.query(
      `UPDATE wallets
          SET name = COALESCE($3, name),
              color = COALESCE($4, color),
              icon = COALESCE($5, icon),
              is_archived = COALESCE($6, is_archived),
              rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [
        walletId,
        userId,
        dto.name ?? null,
        dto.color ?? null,
        dto.icon ?? null,
        dto.is_archived ?? null,
      ],
    );
    const row = await this.findById(userId, walletId);
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ví');
    return row;
  }

  /**
   * Xoá mềm. Giữ bản ghi để đồng bộ offline còn biết ví đã bị xoá, và để
   * giao dịch cũ vẫn tham chiếu được.
   */
  async remove(
    userId: string,
    walletId: string,
    rev?: number,
  ): Promise<WalletRow> {
    const current = await this.findById(userId, walletId);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy ví');
    if (rev !== undefined && rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }

    await this.db.query(
      `UPDATE wallets
          SET deleted_at = now(), rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [walletId, userId],
    );
    const row = await this.findById(userId, walletId, true);
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ví');
    return row;
  }

  /**
   * Số ví đang hoạt động tối đa theo gói.
   * Gói free: 3. Các gói trả phí: không giới hạn (dùng hằng lớn thay vì
   * NULL để câu SQL so sánh vẫn đơn giản).
   */
  private async activeWalletLimit(userId: string): Promise<number> {
    const row = await this.db.one<{ plan: string; expired: boolean }>(
      `SELECT plan, (plan_expires_at IS NOT NULL AND plan_expires_at <= now()) AS expired
         FROM users WHERE id = $1`,
      [userId],
    );
    // Không có hồ sơ (hoặc gói đã hết hạn) thì áp mức free.
    if (!row || row.expired || row.plan === 'free') {
      return FREE_PLAN_ACTIVE_WALLETS;
    }
    return PAID_PLAN_ACTIVE_WALLETS;
  }

  private async findById(
    userId: string,
    walletId: string,
    includeDeleted = false,
  ): Promise<WalletRow | null> {
    const row = await this.db.one<WalletRow>(
      `SELECT ${COLUMNS}
         FROM wallets w
        WHERE w.id = $1 AND w.user_id = $2${
          includeDeleted ? '' : ' AND w.deleted_at IS NULL'
        }`,
      [walletId, userId],
    );
    return row ? toWallet(row) : null;
  }
}

function toWallet(row: WalletRow): WalletRow {
  return {
    ...row,
    initial_balance: Number(row.initial_balance),
    balance: Number(row.balance),
    deleted_at: row.deleted_at ? new Date(row.deleted_at).toISOString() : null,
  };
}
