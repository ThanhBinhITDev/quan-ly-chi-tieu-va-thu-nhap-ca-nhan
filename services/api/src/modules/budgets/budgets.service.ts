import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import {
  daysLeftInPeriod,
  percent,
  vietnamMonthRange,
} from '../reports/report-calculator.js';
import type {
  CreateBudgetDto,
  ListBudgetsQuery,
  UpdateBudgetDto,
} from './budget.dto.js';

export interface BudgetRow {
  id: string;
  category_id: string | null;
  amount: string | number;
  period: string;
  start_date: string;
  end_date: string | null;
  rev: number;
}

export interface BudgetProgressItem {
  budget_id: string;
  category_id: string | null;
  name: string;
  amount: number;
  spent: number;
  remaining: number;
  used_pct: number;
  status: 'ok' | 'notice' | 'warning' | 'exceeded';
  days_left: number;
}

const COLUMNS = `id, category_id, amount, period, start_date, end_date, rev`;

@Injectable()
export class BudgetsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(userId: string, query: ListBudgetsQuery): Promise<BudgetRow[]> {
    const params: unknown[] = [userId];
    let filter = '';
    if (query.active) {
      const today = vietnamToday();
      params.push(today);
      filter = ` AND start_date <= $${params.length}::date
                 AND (end_date IS NULL OR end_date >= $${params.length}::date)`;
    }
    const rows = await this.db.query<BudgetRow>(
      `SELECT ${COLUMNS}
         FROM budgets
        WHERE user_id = $1 AND deleted_at IS NULL${filter}
        ORDER BY category_id NULLS FIRST, start_date DESC`,
      params,
    );
    return rows.map(toBudget);
  }

  async create(userId: string, dto: CreateBudgetDto): Promise<BudgetRow> {
    const existingById = await this.db.one<{ id: string; user_id: string }>(
      `SELECT id, user_id FROM budgets WHERE id = $1`,
      [dto.id],
    );
    if (existingById) {
      if (existingById.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Ngân sách thuộc người dùng khác');
      }
      const row = await this.findById(userId, dto.id);
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ngân sách');
      return row;
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

    // Hợp đồng 6.2: đã có ngân sách đang áp dụng thì phải PATCH, không POST.
    const active = await this.db.one<{ id: string }>(
      `SELECT id FROM budgets
        WHERE user_id = $1
          AND COALESCE(category_id, '00000000-0000-0000-0000-000000000000'::uuid)
            = COALESCE($2::uuid, '00000000-0000-0000-0000-000000000000'::uuid)
          AND period = $3
          AND deleted_at IS NULL
          AND end_date IS NULL`,
      [userId, dto.category_id ?? null, dto.period],
    );
    if (active) {
      throw new ApiError(
        'RULE_VIOLATION',
        'Đã có ngân sách đang áp dụng, hãy PATCH để sửa',
        { details: { budget_id: active.id } },
      );
    }

    const row = await this.db.one<BudgetRow>(
      `INSERT INTO budgets (id, user_id, category_id, amount, period, start_date)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING ${COLUMNS}`,
      [
        dto.id,
        userId,
        dto.category_id ?? null,
        dto.amount,
        dto.period,
        dto.start_date,
      ],
    );
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được ngân sách');
    return toBudget(row);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateBudgetDto,
  ): Promise<BudgetRow> {
    const current = await this.findById(userId, id, true);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy ngân sách');
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }

    const row = await this.db.one<BudgetRow>(
      `UPDATE budgets
          SET amount = COALESCE($3, amount),
              end_date = COALESCE($4, end_date),
              deleted_at = COALESCE($5, deleted_at),
              rev = rev + 1
        WHERE id = $1 AND user_id = $2
        RETURNING ${COLUMNS}`,
      [id, userId, dto.amount ?? null, dto.end_date ?? null, dto.deleted_at ?? null],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ngân sách');
    return toBudget(row);
  }

  /**
   * Tiến độ theo hợp đồng 6.3. `status` do server quyết định để
   * thông báo đẩy và giao diện dùng chung một ngưỡng.
   */
  async progress(userId: string): Promise<{
    as_of: string;
    items: BudgetProgressItem[];
  }> {
    const asOf = vietnamToday();
    const [year, month] = asOf.split('-').map(Number);
    const range = vietnamMonthRange(year, month);
    const monthStart = range.start;
    const monthEnd = range.end;

    const budgets = await this.db.query<{
      id: string;
      category_id: string | null;
      amount: string;
      period: string;
      start_date: string;
      category_name: string | null;
    }>(
      `SELECT b.id, b.category_id, b.amount::text AS amount, b.period,
              b.start_date::text AS start_date, c.name AS category_name
         FROM budgets b
         LEFT JOIN categories c ON c.id = b.category_id
        WHERE b.user_id = $1
          AND b.deleted_at IS NULL
          AND b.start_date <= $2::date
          AND (b.end_date IS NULL OR b.end_date >= $2::date)
        ORDER BY b.category_id NULLS FIRST`,
      [userId, asOf],
    );

    const spentRows = await this.db.query<{
      category_id: string | null;
      total: string;
    }>(
      `SELECT category_id, SUM(amount)::text AS total
         FROM transactions
        WHERE user_id = $1
          AND deleted_at IS NULL
          AND type = 'expense'
          AND occurred_on BETWEEN $2::date AND $3::date
        GROUP BY category_id`,
      [userId, monthStart, monthEnd],
    );
    const spentByCategory = new Map<string | null, number>();
    let totalSpent = 0;
    for (const row of spentRows) {
      const total = Number(row.total);
      spentByCategory.set(row.category_id, total);
      totalSpent += total;
    }

    const periodEnd = new Date(`${monthEnd}T00:00:00Z`);
    const periodStart = new Date(`${monthStart}T00:00:00Z`);
    const today = new Date(`${asOf}T00:00:00Z`);
    const daysLeft = daysLeftInPeriod(today, periodStart, periodEnd);

    const items = budgets.map((budget) => {
      const amount = Number(budget.amount);
      const spent =
        budget.category_id === null
          ? totalSpent
          : (spentByCategory.get(budget.category_id) ?? 0);
      const remaining = amount - spent;
      const usedPct = percent(spent, amount);
      return {
        budget_id: budget.id,
        category_id: budget.category_id,
        name: budget.category_name ?? 'Tổng',
        amount,
        spent,
        remaining,
        used_pct: usedPct,
        status: budgetStatus(usedPct),
        days_left: daysLeft,
      };
    });

    return { as_of: asOf, items };
  }

  private async findById(
    userId: string,
    id: string,
    includeDeleted = false,
  ): Promise<BudgetRow | null> {
    const row = await this.db.one<BudgetRow>(
      `SELECT ${COLUMNS}
         FROM budgets
        WHERE id = $1 AND user_id = $2 ${includeDeleted ? '' : 'AND deleted_at IS NULL'}`,
      [id, userId],
    );
    return row ? toBudget(row) : null;
  }
}

export function budgetStatus(
  usedPct: number,
): 'ok' | 'notice' | 'warning' | 'exceeded' {
  if (usedPct >= 100) return 'exceeded';
  if (usedPct >= 90) return 'warning';
  if (usedPct >= 70) return 'notice';
  return 'ok';
}

/** Ngày hôm nay theo giờ Việt Nam, dạng YYYY-MM-DD. */
export function vietnamToday(now = new Date()): string {
  const shifted = new Date(now.getTime() + 7 * 3_600_000);
  return shifted.toISOString().slice(0, 10);
}

function toBudget(row: BudgetRow): BudgetRow {
  return { ...row, amount: Number(row.amount) };
}
