import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import {
  dailyLimit,
  daysLeftInPeriod,
  percent,
  vietnamMonthRange,
} from './report-calculator.js';

export interface MonthSummary {
  period: { start: string; end: string; days_left: number };
  income: number;
  expense: number;
  remaining: number;
  daily_limit: number;
  budget: { total: number; used_pct: number };
  by_category: Array<{
    id: string;
    name: string;
    total: number;
    pct: number;
  }>;
  by_day: Array<{ date: string; total: number }>;
  computed_at: string;
}

@Injectable()
export class ReportsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async monthSummary(
    userId: string,
    year: number,
    month: number,
  ): Promise<MonthSummary> {
    if (month < 1 || month > 12) {
      throw new ApiError('VALIDATION_FAILED', 'month phải trong khoảng 1..12', {
        field: 'month',
      });
    }
    const { start, end } = vietnamMonthRange(year, month);

    const totals = await this.db.one<{ income: string; expense: string }>(
      `SELECT
         COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0)::text AS income,
         COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0)::text AS expense
         FROM transactions
        WHERE user_id = $1
          AND deleted_at IS NULL
          AND occurred_on BETWEEN $2::date AND $3::date`,
      [userId, start, end],
    );
    const income = Number(totals?.income ?? 0);
    const expense = Number(totals?.expense ?? 0);

    // Ngân sách tổng đang áp dụng: category_id IS NULL, period = 'month'.
    const budget = await this.db.one<{ amount: string }>(
      `SELECT amount::text AS amount
         FROM budgets
        WHERE user_id = $1
          AND category_id IS NULL
          AND period = 'month'
          AND deleted_at IS NULL
          AND start_date <= $3::date
          AND (end_date IS NULL OR end_date >= $2::date)
        ORDER BY start_date DESC
        LIMIT 1`,
      [userId, start, end],
    );
    const budgetTotal = Number(budget?.amount ?? 0);
    const remaining = budgetTotal - expense;

    // today lấy theo giờ Việt Nam để days_left đúng với người dùng.
    const today = new Date(
      new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }),
    );
    const periodEnd = new Date(`${end}T00:00:00Z`);
    const periodStart = new Date(`${start}T00:00:00Z`);
    const daysLeft = daysLeftInPeriod(today, periodStart, periodEnd);

    const byCategory = await this.db.query<{
      id: string;
      name: string;
      total: string;
    }>(
      `SELECT c.id, c.name, SUM(t.amount)::text AS total
         FROM transactions t
         JOIN categories c ON c.id = t.category_id
        WHERE t.user_id = $1
          AND t.deleted_at IS NULL
          AND t.type = 'expense'
          AND t.occurred_on BETWEEN $2::date AND $3::date
        GROUP BY c.id, c.name
        ORDER BY SUM(t.amount) DESC`,
      [userId, start, end],
    );

    const byDay = await this.db.query<{ date: string; total: string }>(
      `SELECT occurred_on::text AS date, SUM(amount)::text AS total
         FROM transactions
        WHERE user_id = $1
          AND deleted_at IS NULL
          AND type = 'expense'
          AND occurred_on BETWEEN $2::date AND $3::date
        GROUP BY occurred_on
        ORDER BY occurred_on`,
      [userId, start, end],
    );

    return {
      period: { start, end, days_left: daysLeft },
      income,
      expense,
      remaining,
      daily_limit: dailyLimit(remaining, daysLeft),
      budget: { total: budgetTotal, used_pct: percent(expense, budgetTotal) },
      by_category: byCategory.map((row) => ({
        id: row.id,
        name: row.name,
        total: Number(row.total),
        pct: percent(Number(row.total), expense),
      })),
      by_day: byDay.map((row) => ({ date: row.date, total: Number(row.total) })),
      computed_at: new Date().toISOString(),
    };
  }
}
