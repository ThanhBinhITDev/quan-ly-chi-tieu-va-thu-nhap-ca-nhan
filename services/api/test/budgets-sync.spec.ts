import { describe, expect, it } from 'vitest';

import { budgetStatus, BudgetsService, vietnamToday } from '../src/modules/budgets/budgets.service.js';
import { CategoriesService } from '../src/modules/categories/categories.service.js';
import { SyncService } from '../src/modules/sync/sync.service.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '99999999-9999-4999-8999-999999999999';
const BUDGET = '55555555-5555-4555-8555-555555555555';
const CATEGORY = '66666666-6666-4666-8666-666666666666';
const TX = '44444444-4444-4444-8444-444444444444';
const DEVICE = '77777777-7777-4777-8777-777777777777';

describe('budgetStatus (ngưỡng do server quyết định)', () => {
  it('dưới 70% là ok', () => {
    expect(budgetStatus(0)).toBe('ok');
    expect(budgetStatus(69.9)).toBe('ok');
  });

  it('70–89% là notice', () => {
    expect(budgetStatus(70)).toBe('notice');
    expect(budgetStatus(89.9)).toBe('notice');
  });

  it('90–99% là warning', () => {
    expect(budgetStatus(90)).toBe('warning');
    expect(budgetStatus(99.9)).toBe('warning');
  });

  it('từ 100% là exceeded', () => {
    expect(budgetStatus(100)).toBe('exceeded');
    expect(budgetStatus(140)).toBe('exceeded');
  });
});

describe('vietnamToday', () => {
  it('lấy theo UTC+7, không theo UTC', () => {
    // 2026-11-19T18:00Z = 2026-11-20 01:00 giờ Việt Nam
    expect(vietnamToday(new Date('2026-11-19T18:00:00Z'))).toBe('2026-11-20');
  });
});

describe('BudgetsService', () => {
  it('chặn tạo ngân sách tổng thứ hai', async () => {
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM budgets WHERE id', [])
      .on('COALESCE(category_id', [{ id: BUDGET }]);
    const service = new BudgetsService(db);

    await expect(
      service.create(USER, {
        id: BUDGET,
        amount: 3_000_000,
        period: 'month',
        start_date: '2026-11-01',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('tiến độ tính spent chỉ từ type = expense và trả status', async () => {
    const db = new FakeDatabase()
      .on('FROM budgets b', [
        {
          id: BUDGET,
          category_id: null,
          amount: '3000000',
          period: 'month',
          start_date: '2026-11-01',
          category_name: null,
        },
      ])
      .on('SELECT category_id, SUM(amount)', [{ category_id: null, total: '295000' }]);
    const service = new BudgetsService(db);

    const progress = await service.progress(USER);
    expect(progress.items).toHaveLength(1);
    expect(progress.items[0]).toMatchObject({
      name: 'Tổng',
      amount: 3_000_000,
      spent: 295_000,
      remaining: 2_705_000,
      status: 'ok',
    });
    expect(progress.as_of).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('vượt ngân sách thì remaining âm và status exceeded', async () => {
    const db = new FakeDatabase()
      .on('FROM budgets b', [
        {
          id: BUDGET,
          category_id: null,
          amount: '100000',
          period: 'month',
          start_date: '2026-11-01',
          category_name: null,
        },
      ])
      .on('SELECT category_id, SUM(amount)', [{ category_id: null, total: '150000' }]);
    const service = new BudgetsService(db);

    const item = (await service.progress(USER)).items[0];
    expect(item.remaining).toBe(-50_000);
    expect(item.status).toBe('exceeded');
  });
});

describe('CategoriesService', () => {
  it('không cho ghi đè danh mục hệ thống', async () => {
    const db = new FakeDatabase().on('SELECT id, user_id FROM categories WHERE id', [
      { id: CATEGORY, user_id: null },
    ]);
    const service = new CategoriesService(db);

    await expect(
      service.create(USER, { id: CATEGORY, name: 'Ăn uống', type: 'expense' }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('không sửa được danh mục hệ thống', async () => {
    const db = new FakeDatabase().on('SELECT id, user_id, name, type', [
      {
        id: CATEGORY,
        user_id: null,
        name: 'Ăn uống',
        type: 'expense',
        icon: null,
        color: null,
        parent_id: null,
        is_system: true,
        sort_order: 0,
        rev: 1,
      },
    ]);
    const service = new CategoriesService(db);

    await expect(
      service.update(USER, CATEGORY, { name: 'Đổi', rev: 2 }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('SyncService', () => {
  const insertChange = {
    table: 'transactions' as const,
    op: 'insert' as const,
    id: TX,
    rev: 1,
    data: {
      wallet_id: '22222222-2222-4222-8222-222222222222',
      type: 'expense',
      amount: 35_000,
      occurred_at: '2026-11-19T04:00:00Z',
    },
  };

  it('chèn bản ghi mới khi server chưa có', async () => {
    const db = new FakeDatabase().on('SELECT rev, to_jsonb(t)', []);
    const service = new SyncService(db);

    const result = await service.push(USER, {
      device_id: DEVICE,
      changes: [insertChange],
    });

    expect(result.applied).toHaveLength(1);
    expect(result.applied[0]).toMatchObject({ id: TX, status: 'ok' });
    expect(result.conflicts).toHaveLength(0);
  });

  it('rev client <= rev server thì trả conflict kèm dữ liệu server', async () => {
    const db = new FakeDatabase().on('SELECT rev, to_jsonb(t)', [
      { rev: 4, payload: { id: TX, amount: 40_000, note: 'server' } },
    ]);
    const service = new SyncService(db);

    const result = await service.push(USER, {
      device_id: DEVICE,
      changes: [{ ...insertChange, op: 'update', rev: 3 }],
    });

    expect(result.applied).toHaveLength(0);
    expect(result.conflicts[0]).toMatchObject({
      id: TX,
      status: 'conflict',
      server_rev: 4,
    });
    expect(result.conflicts[0].server_data).toMatchObject({ note: 'server' });
  });

  it('rev client = rev server + 1 thì áp dụng', async () => {
    const db = new FakeDatabase().on('SELECT rev, to_jsonb(t)', [
      { rev: 2, payload: { id: TX } },
    ]);
    const service = new SyncService(db);

    const result = await service.push(USER, {
      device_id: DEVICE,
      changes: [{ ...insertChange, op: 'update', rev: 3 }],
    });

    expect(result.applied[0]).toMatchObject({ status: 'ok', rev: 3 });
  });

  it('xóa mềm bản ghi chưa có vẫn coi như xong (idempotent)', async () => {
    const db = new FakeDatabase().on('SELECT rev, to_jsonb(t)', []);
    const service = new SyncService(db);

    const result = await service.push(USER, {
      device_id: DEVICE,
      changes: [{ ...insertChange, op: 'delete', rev: 2, data: {} }],
    });

    expect(result.applied[0]).toMatchObject({ status: 'ok' });
    expect(result.conflicts).toHaveLength(0);
  });

  it('không nhận cột lạ ngoài danh sách cho phép', async () => {
    const db = new FakeDatabase().on('SELECT rev, to_jsonb(t)', [
      { rev: 1, payload: { id: TX } },
    ]);
    const service = new SyncService(db);

    // rev hợp lệ nhưng data chỉ có cột cấm -> không ghi cột nào, vẫn tăng rev.
    const result = await service.push(USER, {
      device_id: DEVICE,
      changes: [
        {
          ...insertChange,
          op: 'update',
          rev: 2,
          data: { user_id: OTHER, rev: 99, id: OTHER },
        },
      ],
    });

    expect(result.applied[0]).toMatchObject({ status: 'ok' });
  });

  it('pull trả next_since và has_more', async () => {
    const db = new FakeDatabase().on('to_jsonb(t) AS payload', [
      {
        id: TX,
        rev: 2,
        updated_at: new Date('2026-11-19T05:00:00Z'),
        deleted_at: null,
        payload: { id: TX },
      },
    ]);
    const service = new SyncService(db);

    const result = await service.pull(USER, {
      since: '2026-11-19T04:00:00.000Z',
      limit: 100,
    });

    expect(result.changes[0]).toMatchObject({ id: TX, op: 'update', rev: 2 });
    expect(result.next_since).toBe('2026-11-19T05:00:00.000Z');
    expect(result.has_more).toBe(false);
  });
});
