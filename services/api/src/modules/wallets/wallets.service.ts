import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type { CreateWalletDto, UpdateWalletDto } from './wallet.dto.js';

export interface WalletRow {
  id: string;
  name: string;
  type: string;
  initial_balance: string | number;
  color: string | null;
  icon: string | null;
  is_archived: boolean;
  rev: number;
}

/** Gói miễn phí: tối đa 3 ví đang hoạt động (hợp đồng API, mục 4.2). */
const FREE_PLAN_ACTIVE_WALLETS = 3;

@Injectable()
export class WalletsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(userId: string): Promise<WalletRow[]> {
    const rows = await this.db.query<WalletRow>(
      `SELECT id, name, type, initial_balance, color, icon, is_archived, rev
         FROM wallets
        WHERE user_id = $1 AND deleted_at IS NULL
        ORDER BY sort_order, created_at`,
      [userId],
    );
    return rows.map(toWallet);
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
    if (Number(active?.count ?? 0) >= FREE_PLAN_ACTIVE_WALLETS) {
      throw new ApiError('PLAN_LIMIT', 'Gói miễn phí chỉ cho phép 3 ví đang hoạt động', {
        details: {
          limit: FREE_PLAN_ACTIVE_WALLETS,
          current: Number(active?.count ?? 0),
        },
      });
    }

    const row = await this.db.one<WalletRow>(
      `INSERT INTO wallets (id, user_id, name, type, initial_balance, color, icon)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, name, type, initial_balance, color, icon, is_archived, rev`,
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
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được ví');
    return toWallet(row);
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

    const row = await this.db.one<WalletRow>(
      `UPDATE wallets
          SET name = COALESCE($3, name),
              color = COALESCE($4, color),
              icon = COALESCE($5, icon),
              is_archived = COALESCE($6, is_archived),
              rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
        RETURNING id, name, type, initial_balance, color, icon, is_archived, rev`,
      [
        walletId,
        userId,
        dto.name ?? null,
        dto.color ?? null,
        dto.icon ?? null,
        dto.is_archived ?? null,
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ví');
    return toWallet(row);
  }

  private async findById(userId: string, walletId: string): Promise<WalletRow | null> {
    const row = await this.db.one<WalletRow>(
      `SELECT id, name, type, initial_balance, color, icon, is_archived, rev
         FROM wallets
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [walletId, userId],
    );
    return row ? toWallet(row) : null;
  }
}

function toWallet(row: WalletRow): WalletRow {
  return { ...row, initial_balance: Number(row.initial_balance) };
}
