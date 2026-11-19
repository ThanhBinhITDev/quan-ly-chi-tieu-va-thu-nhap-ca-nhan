import { randomBytes } from 'node:crypto';

import { Inject, Injectable } from '@nestjs/common';

import type { Database } from '../../common/db/database.js';
import { DATABASE } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type {
  CreateGroupDto,
  CreateSharedExpenseDto,
  JoinGroupDto,
  SettleDto,
} from './group.dto.js';
import { minimizeSettlements } from './settlement.js';

export interface GroupView {
  id: string;
  name: string;
  role: 'owner' | 'member';
  member_count: number;
  invite_code: string | null;
  my_balance: number;
  rev: number;
  updated_at: string;
}

const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

@Injectable()
export class GroupsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(userId: string): Promise<{ items: GroupView[] }> {
    const rows = await this.db.query<{
      id: string;
      name: string;
      role: string;
      member_count: string;
      invite_code: string;
      owner_id: string;
      rev: number;
      updated_at: Date | string;
    }>(
      `SELECT g.id, g.name, gm.role, g.invite_code, g.owner_id, g.rev, g.updated_at,
              (SELECT count(*)::text FROM group_members m
                WHERE m.group_id = g.id AND m.left_at IS NULL) AS member_count
         FROM groups g
         JOIN group_members gm ON gm.group_id = g.id
        WHERE gm.user_id = $1 AND gm.left_at IS NULL AND g.deleted_at IS NULL
        ORDER BY g.updated_at DESC`,
      [userId],
    );

    const items: GroupView[] = [];
    for (const row of rows) {
      const balances = await this.balanceMap(row.id);
      items.push({
        id: row.id,
        name: row.name,
        role: row.role === 'owner' ? 'owner' : 'member',
        member_count: Number(row.member_count),
        // Mã mời chỉ trả cho chủ nhóm (hợp đồng 8.1).
        invite_code: row.owner_id === userId ? row.invite_code : null,
        my_balance: balances.get(userId)?.net ?? 0,
        rev: row.rev,
        updated_at: toIso(row.updated_at),
      });
    }
    return { items };
  }

  async create(userId: string, dto: CreateGroupDto): Promise<GroupView> {
    return this.db.transaction(async (tx) => {
      const existing = await tx.one<{ owner_id: string }>(
        `SELECT owner_id FROM groups WHERE id = $1`,
        [dto.id],
      );
      if (existing) {
        if (existing.owner_id !== userId) {
          throw new ApiError('FORBIDDEN', 'Nhóm thuộc người dùng khác');
        }
        const mine = await this.findById(tx, userId, dto.id);
        if (!mine) throw new ApiError('NOT_FOUND', 'Không tìm thấy nhóm');
        return mine;
      }

      const inviteCode = generateInviteCode();
      const group = await tx.one<{ id: string; rev: number; updated_at: Date }>(
        `INSERT INTO groups (id, name, owner_id, invite_code)
         VALUES ($1, $2, $3, $4)
         RETURNING id, rev, updated_at`,
        [dto.id, dto.name, userId, inviteCode],
      );
      if (!group) throw new ApiError('INTERNAL', 'Không tạo được nhóm');

      await tx.query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, 'owner')`,
        [dto.id, userId],
      );

      return {
        id: group.id,
        name: dto.name,
        role: 'owner',
        member_count: 1,
        invite_code: inviteCode,
        my_balance: 0,
        rev: group.rev,
        updated_at: toIso(group.updated_at),
      };
    });
  }

  async join(userId: string, dto: JoinGroupDto): Promise<GroupView> {
    const code = dto.invite_code.trim().toUpperCase();
    const group = await this.db.one<{
      id: string;
      owner_id: string;
      rev: number;
      updated_at: Date;
    }>(
      `SELECT id, owner_id, rev, updated_at FROM groups
        WHERE invite_code = $1 AND deleted_at IS NULL`,
      [code],
    );
    // Không phân biệt "mã sai" và "nhóm đã xoá" để không dò được mã (8.3).
    if (!group) throw new ApiError('NOT_FOUND', 'Mã mời không hợp lệ');

    const membership = await this.db.one<{ left_at: Date | null }>(
      `SELECT left_at FROM group_members WHERE group_id = $1 AND user_id = $2`,
      [group.id, userId],
    );
    if (membership && !membership.left_at) {
      throw new ApiError('RULE_VIOLATION', 'Bạn đã là thành viên của nhóm này');
    }
    if (membership?.left_at) {
      // Từng rời nhóm: cho vào lại thay vì tạo dòng trùng khoá chính.
      await this.db.query(
        `UPDATE group_members SET left_at = NULL, joined_at = now()
          WHERE group_id = $1 AND user_id = $2`,
        [group.id, userId],
      );
    } else {
      // `group_members.user_id` có khoá ngoại tới `users(id)`. Người mới
      // đăng ký qua Supabase Auth nhưng chưa gọi /v1/me thì chưa có dòng
      // `users`, và INSERT sẽ vi phạm khoá ngoại (trước đây trả 500).
      await this.ensureUserRow(userId);
      await this.db.query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, 'member')`,
        [group.id, userId],
      );
    }

    const view = await this.findById(this.db, userId, group.id);
    if (!view) throw new ApiError('INTERNAL', 'Không đọc lại được nhóm');
    return view;
  }

  /**
   * Số dư: `paid` = tiền người đó đã trả cho nhóm, `owed` = phần phải chịu
   * của các khoản chưa được đánh dấu đã trả.
   */
  async balances(userId: string, groupId: string) {
    await this.assertMember(userId, groupId);
    const rows = await this.db.query<{
      user_id: string;
      display_name: string | null;
      paid: string;
      owed: string;
    }>(
      `SELECT m.user_id::text AS user_id, u.display_name,
              COALESCE(p.paid, 0)::text AS paid,
              COALESCE(o.owed, 0)::text AS owed
         FROM group_members m
         LEFT JOIN users u ON u.id = m.user_id
         LEFT JOIN (
           SELECT payer_id, SUM(amount) AS paid
             FROM shared_expenses
            WHERE group_id = $1 AND deleted_at IS NULL
            GROUP BY payer_id
         ) p ON p.payer_id = m.user_id
         LEFT JOIN (
           SELECT s.user_id, SUM(s.share_amount) AS owed
             FROM shared_shares s
             JOIN shared_expenses e ON e.id = s.expense_id
            WHERE e.group_id = $1 AND e.deleted_at IS NULL
              AND s.settled_at IS NULL
            GROUP BY s.user_id
         ) o ON o.user_id = m.user_id
        WHERE m.group_id = $1 AND m.left_at IS NULL
        ORDER BY m.joined_at`,
      [groupId],
    );

    const items = rows.map((row) => {
      const paid = Number(row.paid);
      const owed = Number(row.owed);
      return {
        user_id: row.user_id,
        display_name: row.display_name ?? '(không tên)',
        paid,
        owed,
        net: paid - owed,
      };
    });

    return {
      items,
      settlements: minimizeSettlements(
        items.map((item) => ({ user_id: item.user_id, net: item.net })),
      ),
    };
  }

  /**
   * Chia tiền: tạo khoản chi, các phần chia, và sinh giao dịch cá nhân
   * cho từng người có phần > 0 (hợp đồng 8.5 bước 4).
   */
  async addExpense(
    userId: string,
    groupId: string,
    dto: CreateSharedExpenseDto,
  ) {
    await this.assertMember(userId, groupId);

    const totalShares = dto.shares.reduce((sum, s) => sum + s.share_amount, 0);
    if (totalShares !== dto.amount) {
      throw new ApiError(
        'RULE_VIOLATION',
        'Tổng phần chia phải bằng số tiền khoản chi',
        { field: 'shares', details: { amount: dto.amount, total_shares: totalShares } },
      );
    }
    const memberIds = new Set(
      (
        await this.db.query<{ user_id: string }>(
          `SELECT user_id FROM group_members
            WHERE group_id = $1 AND left_at IS NULL`,
          [groupId],
        )
      ).map((row) => row.user_id),
    );
    for (const share of dto.shares) {
      if (!memberIds.has(share.user_id)) {
        throw new ApiError(
          'RULE_VIOLATION',
          'Có người không thuộc nhóm trong danh sách chia',
          { field: 'shares', details: { user_id: share.user_id } },
        );
      }
    }

    return this.db.transaction(async (tx) => {
      const existing = await tx.one<{ id: string }>(
        `SELECT id FROM shared_expenses WHERE id = $1`,
        [dto.id],
      );
      if (existing) {
        // Gửi lại cùng id: không tạo trùng khoản chi lẫn giao dịch cá nhân.
        return this.findExpense(tx, dto.id);
      }

      const group = await tx.one<{ name: string }>(
        `SELECT name FROM groups WHERE id = $1`,
        [groupId],
      );

      await tx.query(
        `INSERT INTO shared_expenses
           (id, group_id, payer_id, amount, note, occurred_on, split_method)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          dto.id,
          groupId,
          userId,
          dto.amount,
          dto.note ?? null,
          dto.occurred_on.slice(0, 10),
          dto.split_method ?? 'equal',
        ],
      );

      for (const share of dto.shares) {
        await tx.query(
          `INSERT INTO shared_shares (expense_id, user_id, share_amount)
           VALUES ($1, $2, $3)`,
          [dto.id, share.user_id, share.share_amount],
        );
      }

      // Bước 4: giao dịch cá nhân cho phần của từng người.
      for (const share of dto.shares) {
        if (share.share_amount <= 0) continue;
        const wallet = await tx.one<{ id: string }>(
          `SELECT id FROM wallets
            WHERE user_id = $1 AND deleted_at IS NULL AND is_archived = false
            ORDER BY sort_order, created_at LIMIT 1`,
          [share.user_id],
        );
        if (!wallet) continue; // Người chưa có ví: bỏ qua, không chặn cả lô.
        await tx.query(
          `INSERT INTO transactions
             (id, user_id, wallet_id, type, amount, note, occurred_at, source)
           VALUES (gen_random_uuid(), $1, $2, 'expense', $3, $4, $5::date, 'manual')`,
          [
            share.user_id,
            wallet.id,
            share.share_amount,
            `Chia tiền nhóm ${group?.name ?? ''}`.trim(),
            dto.occurred_on,
          ],
        );
      }

      return this.findExpense(tx, dto.id);
    });
  }

  /**
   * Chỉ đánh dấu được phần của chính mình (hợp đồng 8.6).
   * Không cho một người xác nhận nợ của người khác.
   */
  async settle(userId: string, groupId: string, dto: SettleDto) {
    await this.assertMember(userId, groupId);
    if (dto.with_user_id === userId) {
      throw new ApiError('RULE_VIOLATION', 'Không thể tất toán với chính mình');
    }

    const result = await this.db.query<{ expense_id: string }>(
      `UPDATE shared_shares s
          SET settled_at = now()
         FROM shared_expenses e
        WHERE e.id = s.expense_id
          AND e.group_id = $1
          AND e.deleted_at IS NULL
          AND s.user_id = $2
          AND s.settled_at IS NULL
          AND e.payer_id = $3
          AND s.share_amount > 0
        RETURNING s.expense_id`,
      [groupId, userId, dto.with_user_id],
    );

    if (result.length === 0) {
      throw new ApiError(
        'RULE_VIOLATION',
        'Không có khoản chưa tất toán với người này',
      );
    }

    return this.balances(userId, groupId);
  }

  /**
   * Tạo dòng `users` tối thiểu nếu chưa có, để các khoá ngoại tới `users(id)`
   * không bị vi phạm. Dùng khi thao tác không đi qua /v1/me.
   *
   * `users_contact` bắt buộc có email hoặc phone; caller đã xác thực JWT nên
   * id luôn tồn tại bên Supabase Auth. Nếu thiếu cả hai trường, dùng email
   * dẫn xuất từ id để không chặn người dùng hợp lệ.
   */
  private async ensureUserRow(userId: string): Promise<void> {
    await this.db.query(
      `INSERT INTO users (id, email, display_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (id) DO NOTHING`,
      [userId, `u-${userId}@studentfinance.local`, 'Người dùng'],
    );
  }

  private async findById(
    db: Database,
    userId: string,
    groupId: string,
  ): Promise<GroupView | null> {
    const row = await db.one<{
      id: string;
      name: string;
      role: string;
      invite_code: string;
      owner_id: string;
      rev: number;
      updated_at: Date | string;
      member_count: string;
    }>(
      `SELECT g.id, g.name, gm.role, g.invite_code, g.owner_id, g.rev, g.updated_at,
              (SELECT count(*)::text FROM group_members m
                WHERE m.group_id = g.id AND m.left_at IS NULL) AS member_count
         FROM groups g
         JOIN group_members gm ON gm.group_id = g.id
        WHERE g.id = $1 AND gm.user_id = $2 AND gm.left_at IS NULL
          AND g.deleted_at IS NULL`,
      [groupId, userId],
    );
    if (!row) return null;
    return {
      id: row.id,
      name: row.name,
      role: row.role === 'owner' ? 'owner' : 'member',
      member_count: Number(row.member_count),
      invite_code: row.owner_id === userId ? row.invite_code : null,
      my_balance: 0,
      rev: row.rev,
      updated_at: toIso(row.updated_at),
    };
  }

  private async findExpense(db: Database, expenseId: string) {
    const expense = await db.one<{
      id: string;
      group_id: string;
      payer_id: string;
      amount: string;
      note: string | null;
      occurred_on: Date | string;
      split_method: string;
      rev: number;
    }>(
      `SELECT id, group_id, payer_id, amount::text AS amount, note,
              occurred_on, split_method, rev
         FROM shared_expenses WHERE id = $1 AND deleted_at IS NULL`,
      [expenseId],
    );
    if (!expense) throw new ApiError('NOT_FOUND', 'Không tìm thấy khoản chi');
    const shares = await db.query<{
      user_id: string;
      share_amount: string;
      settled_at: Date | null;
    }>(
      `SELECT user_id, share_amount::text AS share_amount, settled_at
         FROM shared_shares WHERE expense_id = $1 ORDER BY share_amount DESC`,
      [expenseId],
    );
    return {
      id: expense.id,
      group_id: expense.group_id,
      payer_id: expense.payer_id,
      amount: Number(expense.amount),
      note: expense.note,
      occurred_on: String(expense.occurred_on).slice(0, 10),
      split_method: expense.split_method,
      rev: expense.rev,
      shares: shares.map((share) => ({
        user_id: share.user_id,
        share_amount: Number(share.share_amount),
        settled_at: share.settled_at ? toIso(share.settled_at) : null,
      })),
    };
  }

  private async assertMember(userId: string, groupId: string): Promise<void> {
    const member = await this.db.one<{ user_id: string }>(
      `SELECT user_id FROM group_members
        WHERE group_id = $1 AND user_id = $2 AND left_at IS NULL`,
      [groupId, userId],
    );
    if (!member) {
      throw new ApiError('FORBIDDEN', 'Bạn không thuộc nhóm này');
    }
  }

  private async balanceMap(groupId: string): Promise<Map<string, { net: number }>> {
    const rows = await this.db.query<{ user_id: string; net: string }>(
      `SELECT m.user_id::text AS user_id,
              (COALESCE(p.paid, 0) - COALESCE(o.owed, 0))::text AS net
         FROM group_members m
         LEFT JOIN (
           SELECT payer_id, SUM(amount) AS paid FROM shared_expenses
            WHERE group_id = $1 AND deleted_at IS NULL GROUP BY payer_id
         ) p ON p.payer_id = m.user_id
         LEFT JOIN (
           SELECT s.user_id, SUM(s.share_amount) AS owed
             FROM shared_shares s
             JOIN shared_expenses e ON e.id = s.expense_id
            WHERE e.group_id = $1 AND e.deleted_at IS NULL AND s.settled_at IS NULL
            GROUP BY s.user_id
         ) o ON o.user_id = m.user_id
        WHERE m.group_id = $1 AND m.left_at IS NULL`,
      [groupId],
    );
    return new Map(rows.map((row) => [row.user_id, { net: Number(row.net) }]));
  }
}

/** Mã mời 8 ký tự, bỏ các ký tự dễ nhầm (0/O, 1/I). */
export function generateInviteCode(length = 8): string {
  const bytes = randomBytes(length);
  let code = '';
  for (let i = 0; i < length; i += 1) {
    code += INVITE_ALPHABET[bytes[i] % INVITE_ALPHABET.length];
  }
  return code;
}

function toIso(value: Date | string): string {
  return value instanceof Date
    ? value.toISOString()
    : new Date(value).toISOString();
}
