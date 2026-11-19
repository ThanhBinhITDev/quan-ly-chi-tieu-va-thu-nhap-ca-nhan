import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import { vietnamToday } from '../budgets/budgets.service.js';
import type { CreateGoalDto, UpdateGoalDto } from './goal.dto.js';

export interface GoalRow {
  id: string;
  name: string;
  target_amount: string | number;
  saved_amount: string | number;
  deadline: string | null;
  icon: string | null;
  is_completed: boolean;
  rev: number;
  updated_at: Date | string;
}

export interface GoalView extends Omit<GoalRow, 'target_amount' | 'saved_amount'> {
  target_amount: number;
  saved_amount: number;
  progress_pct: number;
}

const COLUMNS = `id, name, target_amount, saved_amount, deadline, icon,
       is_completed, rev, updated_at`;

@Injectable()
export class GoalsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(userId: string): Promise<{ items: GoalView[] }> {
    const rows = await this.db.query<GoalRow>(
      `SELECT ${COLUMNS}
         FROM goals
        WHERE user_id = $1 AND deleted_at IS NULL
        ORDER BY is_completed, COALESCE(deadline, 'infinity'::date), created_at DESC`,
      [userId],
    );
    return { items: rows.map(toView) };
  }

  async create(userId: string, dto: CreateGoalDto): Promise<GoalView> {
    if (dto.deadline && dto.deadline.slice(0, 10) < vietnamToday()) {
      throw new ApiError('RULE_VIOLATION', 'Hạn chót không được ở quá khứ', {
        field: 'deadline',
      });
    }

    const existing = await this.db.one<{ id: string; user_id: string }>(
      `SELECT id, user_id FROM goals WHERE id = $1`,
      [dto.id],
    );
    if (existing) {
      if (existing.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Mục tiêu thuộc người dùng khác');
      }
      const row = await this.findOne(userId, dto.id);
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy mục tiêu');
      return row;
    }

    const row = await this.db.one<GoalRow>(
      `INSERT INTO goals (id, user_id, name, target_amount, deadline, icon)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING ${COLUMNS}`,
      [
        dto.id,
        userId,
        dto.name,
        dto.target_amount,
        dto.deadline?.slice(0, 10) ?? null,
        dto.icon ?? null,
      ],
    );
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được mục tiêu');
    return toView(row);
  }

  /**
   * `saved_amount` là số tuyệt đối do client gửi, nên gọi lại nhiều lần
   * với cùng rev/data là idempotent, không cộng lặp khi retry.
   */
  async update(
    userId: string,
    id: string,
    dto: UpdateGoalDto,
  ): Promise<GoalView> {
    const current = await this.findOneWithRev(userId, id);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy mục tiêu');
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }

    const row = await this.db.one<GoalRow>(
      `UPDATE goals
          SET name = COALESCE($3, name),
              target_amount = COALESCE($4, target_amount),
              saved_amount = COALESCE($5, saved_amount),
              deadline = COALESCE($6, deadline),
              icon = COALESCE($7, icon),
              is_completed = COALESCE($8, is_completed),
              rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
        RETURNING ${COLUMNS}`,
      [
        id,
        userId,
        dto.name ?? null,
        dto.target_amount ?? null,
        dto.saved_amount ?? null,
        dto.deadline?.slice(0, 10) ?? null,
        dto.icon ?? null,
        dto.is_completed ?? null,
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy mục tiêu');
    return toView(row);
  }

  /** Xoá mềm; trả 204 ở controller. */
  async remove(userId: string, id: string): Promise<void> {
    const row = await this.db.one<{ id: string }>(
      `UPDATE goals
          SET deleted_at = now(), rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
        RETURNING id`,
      [id, userId],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy mục tiêu');
  }

  private async findOne(userId: string, id: string): Promise<GoalView | null> {
    const row = await this.db.one<GoalRow>(
      `SELECT ${COLUMNS} FROM goals
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [id, userId],
    );
    return row ? toView(row) : null;
  }

  private async findOneWithRev(userId: string, id: string) {
    return this.db.one<{ rev: number; payload: Record<string, unknown> }>(
      `SELECT rev, to_jsonb(g) AS payload FROM goals g
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [id, userId],
    );
  }
}

/** progress_pct = min(100, saved/target*100), 1 chữ số thập phân. */
export function goalProgress(
  savedAmount: number,
  targetAmount: number,
): number {
  if (targetAmount <= 0) return 0;
  const value = (savedAmount / targetAmount) * 100;
  return Math.round(Math.min(100, value) * 10) / 10;
}

function toView(row: GoalRow): GoalView {
  const target = Number(row.target_amount);
  const saved = Number(row.saved_amount);
  return {
    ...row,
    target_amount: target,
    saved_amount: saved,
    progress_pct: goalProgress(saved, target),
    updated_at:
      row.updated_at instanceof Date
        ? row.updated_at.toISOString()
        : new Date(row.updated_at).toISOString(),
  };
}
