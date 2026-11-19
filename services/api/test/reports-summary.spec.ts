import { describe, expect, it } from 'vitest';

import { ReportsService } from '../src/modules/reports/reports.service.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';

/**
 * Dựng DB giả cho `monthSummary`. `previousExpense` là chi tiêu tháng trước,
 * `'0'` nghĩa là tháng trước không có khoản chi nào (không so sánh được).
 */
function db(opts: {
  expense?: string;
  previousExpense?: string;
  byCategory?: Array<{ id: string | null; name: string; total: string }>;
}) {
  return new FakeDatabase()
    .on(`FILTER (WHERE type = 'income')`, [
      { income: '0', expense: opts.expense ?? '170000' },
    ])
    .on('FROM budgets', [{ amount: '500000' }])
    .on('COALESCE(SUM(amount), 0)::text AS expense', [
      { expense: opts.previousExpense ?? '0' },
    ])
    .on('LEFT JOIN categories', opts.byCategory ?? [])
    .on('occurred_on::text AS date', [
      { date: '2026-11-19', total: '100000' },
      { date: '2026-11-20', total: '70000' },
    ]);
}

describe('ReportsService.monthSummary', () => {
  it('gộp chi tiêu chưa gắn danh mục thành "Chưa phân loại"', async () => {
    const service = new ReportsService(
      db({
        byCategory: [
          { id: null, name: 'Chưa phân loại', total: '170000' },
        ],
      }),
    );

    const summary = await service.monthSummary(USER, 2026, 11);

    // Tổng các lát phải bằng tổng chi, nếu không biểu đồ cơ cấu sẽ thiếu tiền.
    const sum = summary.by_category.reduce((acc, row) => acc + row.total, 0);
    expect(sum).toBe(summary.expense);
    expect(summary.by_category[0].id).toBeNull();
    expect(summary.by_category[0].pct).toBe(100);
  });

  it('tính % thay đổi so với tháng trước', async () => {
    const service = new ReportsService(
      db({ expense: '170000', previousExpense: '100000' }),
    );

    const summary = await service.monthSummary(USER, 2026, 11);

    expect(summary.previous.expense).toBe(100000);
    expect(summary.previous.delta_pct).toBe(70);
  });

  it('trả delta_pct = null khi tháng trước chưa chi gì', async () => {
    const service = new ReportsService(
      db({ expense: '170000', previousExpense: '0' }),
    );

    const summary = await service.monthSummary(USER, 2026, 11);

    // null khác 0%: 0% là "không đổi", null là "chưa có mốc so sánh".
    expect(summary.previous.delta_pct).toBeNull();
  });

  it('lấy tháng 12 của năm trước khi tính tháng 1', async () => {
    const fake = db({ expense: '50000', previousExpense: '40000' });
    const service = new ReportsService(fake);

    const summary = await service.monthSummary(USER, 2026, 1);

    expect(summary.previous.delta_pct).toBe(25);
    const prevSql = fake.executed.find((sql) =>
      sql.includes('COALESCE(SUM(amount), 0)::text AS expense'),
    );
    expect(prevSql).toBeDefined();
  });
});
