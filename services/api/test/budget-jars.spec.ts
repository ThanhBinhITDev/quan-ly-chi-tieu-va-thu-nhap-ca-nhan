import { describe, expect, it } from 'vitest';

import { BudgetJarsService } from '../src/modules/budget-jars/budget-jars.service.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '99999999-9999-4999-8999-999999999999';
const JAR = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const JAR2 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const CAT_FOOD = '66666666-6666-4666-8666-666666666666';
const CAT_BUS = '77777777-7777-4777-8777-777777777777';

/** Dòng hũ đúng dạng service đọc từ câu SELECT có `array_agg`. */
function jarRow(overrides: Record<string, unknown> = {}) {
  return {
    id: JAR,
    name: 'Ăn uống',
    share_pct: 40,
    color: null,
    sort_order: 0,
    rev: 1,
    category_ids: [CAT_FOOD],
    ...overrides,
  };
}

describe('BudgetJarsService — chặn tổng tỷ lệ vượt 100%', () => {
  it('báo lỗi khi cộng thêm vượt 100', async () => {
    const db = new FakeDatabase()
      .on('SELECT user_id FROM budget_jars WHERE id', [])
      .on('SUM(share_pct)', [{ total: '80' }]);
    const service = new BudgetJarsService(db);

    await expect(
      service.create(USER, { id: JAR, name: 'Đi lại', share_pct: 30 }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('cho phép khi vừa đúng 100', async () => {
    const db = new FakeDatabase()
      .on('SELECT user_id FROM budget_jars WHERE id', [])
      .on('SUM(share_pct)', [{ total: '80' }])
      .on('FROM categories c', [{ id: CAT_FOOD, jar_id: null, jar_name: null }])
      .on('INSERT INTO budget_jars', [])
      .on('FROM budget_jars j', [jarRow({ name: 'Đi lại', share_pct: 20 })]);
    const service = new BudgetJarsService(db);

    const jar = await service.create(USER, {
      id: JAR,
      name: 'Đi lại',
      share_pct: 20,
      category_ids: [CAT_FOOD],
    });
    expect(jar.share_pct).toBe(20);
  });

  it('khi sửa thì không tính chính hũ đó vào tổng', async () => {
    const db = new FakeDatabase()
      // findById
      .on('WHERE j.id = $1 AND j.user_id = $2', [jarRow({ share_pct: 40 })])
      // tổng của các hũ khác
      .on('SUM(share_pct)', [{ total: '60' }])
      .on('UPDATE budget_jars', [jarRow({ share_pct: 40 })]);
    const service = new BudgetJarsService(db);

    const jar = await service.update(USER, JAR, { rev: 2, share_pct: 40 });
    expect(jar.share_pct).toBe(40);
  });
});

describe('BudgetJarsService — danh mục', () => {
  it('chặn danh mục đã thuộc hũ khác', async () => {
    const db = new FakeDatabase()
      .on('SELECT user_id FROM budget_jars WHERE id', [])
      .on('SUM(share_pct)', [{ total: '0' }])
      .on('FROM categories c', [
        { id: CAT_FOOD, jar_id: JAR, jar_name: 'Ăn uống' },
      ]);
    const service = new BudgetJarsService(db);

    await expect(
      service.create(USER, {
        id: JAR2,
        name: 'Đi chợ',
        share_pct: 10,
        category_ids: [CAT_FOOD],
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('báo danh mục không tồn tại', async () => {
    const db = new FakeDatabase()
      .on('SELECT user_id FROM budget_jars WHERE id', [])
      .on('SUM(share_pct)', [{ total: '0' }])
      .on('FROM categories c', []);
    const service = new BudgetJarsService(db);

    await expect(
      service.create(USER, {
        id: JAR,
        name: 'Ăn uống',
        share_pct: 40,
        category_ids: [CAT_BUS],
      }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('hũ chưa gắn danh mục thì chi tiêu bằng 0, không cộng cả tháng', async () => {
    const db = new FakeDatabase()
      .on('FROM budget_jars j', [
        jarRow({ category_ids: [], share_pct: 50 }),
      ])
      .on('FROM budgets', [{ amount: '1000000', is_total: true }])
      .on('FROM transactions', [{ category_id: CAT_FOOD, total: '300000' }]);
    const service = new BudgetJarsService(db);

    const summary = await service.progress(USER);
    expect(summary.budget_amount).toBe(1000000);
    expect(summary.items[0].amount).toBe(500000);
    expect(summary.items[0].spent).toBe(0);
  });
});

describe('BudgetJarsService — tiến độ', () => {
  it('tính hạn mức theo tỷ lệ và cộng chi tiêu đúng danh mục', async () => {
    const db = new FakeDatabase()
      .on('FROM budget_jars j', [jarRow({ share_pct: 40, category_ids: [CAT_FOOD] })])
      .on('FROM budgets', [{ amount: '2000000', is_total: true }])
      .on('FROM transactions', [
        { category_id: CAT_FOOD, total: '900000' },
        { category_id: CAT_BUS, total: '100000' },
      ]);
    const service = new BudgetJarsService(db);

    const summary = await service.progress(USER);
    const item = summary.items[0];
    expect(item.amount).toBe(800000);
    expect(item.spent).toBe(900000);
    expect(item.remaining).toBe(-100000);
    expect(item.status).toBe('exceeded');
    expect(summary.total_spent).toBe(1000000);
  });

  it('tính phần chưa chia', async () => {
    const db = new FakeDatabase()
      .on('FROM budget_jars j', [jarRow({ share_pct: 30, category_ids: [CAT_FOOD] })])
      .on('FROM budgets', [{ amount: '1000000', is_total: true }])
      .on('FROM transactions', []);
    const service = new BudgetJarsService(db);

    const summary = await service.progress(USER);
    expect(summary.allocated_pct).toBe(30);
    expect(summary.unallocated_pct).toBe(70);
    expect(summary.unallocated_amount).toBe(700000);
  });

  it('chưa có ngân sách tháng thì hạn mức bằng 0, không chia cho 0', async () => {
    const db = new FakeDatabase()
      .on('FROM budget_jars j', [jarRow({ share_pct: 40 })])
      .on('FROM budgets', [])
      .on('FROM transactions', []);
    const service = new BudgetJarsService(db);

    const summary = await service.progress(USER);
    expect(summary.budget_amount).toBe(0);
    expect(summary.items[0].amount).toBe(0);
    expect(summary.items[0].used_pct).toBe(0);
  });

  it('không có ngân sách Tổng thì cộng các ngân sách danh mục', async () => {
    const db = new FakeDatabase()
      .on('FROM budget_jars j', [jarRow({ share_pct: 50, category_ids: [CAT_FOOD] })])
      .on('FROM budgets', [
        { amount: '600000', is_total: false },
        { amount: '400000', is_total: false },
      ])
      .on('FROM transactions', []);
    const service = new BudgetJarsService(db);

    const summary = await service.progress(USER);
    expect(summary.budget_amount).toBe(1000000);
    expect(summary.items[0].amount).toBe(500000);
  });
});

describe('BudgetJarsService — đồng bộ và quyền', () => {
  it('tạo trùng id của người khác thì báo FORBIDDEN', async () => {
    const db = new FakeDatabase().on('SELECT user_id FROM budget_jars WHERE id', [
      { user_id: OTHER },
    ]);
    const service = new BudgetJarsService(db);

    await expect(
      service.create(USER, { id: JAR, name: 'Ăn uống', share_pct: 40 }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('sửa với rev cũ thì báo SYNC_CONFLICT kèm bản mới', async () => {
    const db = new FakeDatabase().on('WHERE j.id = $1 AND j.user_id = $2', [
      jarRow({ rev: 5 }),
    ]);
    const service = new BudgetJarsService(db);

    await expect(
      service.update(USER, JAR, { rev: 2, name: 'Mới' }),
    ).rejects.toMatchObject({ code: 'SYNC_CONFLICT' });
  });

  it('xoá mềm với rev sai thì không đụng dữ liệu', async () => {
    let updated = false;
    const db = new FakeDatabase()
      .on('WHERE j.id = $1 AND j.user_id = $2', [jarRow({ rev: 3 })])
      .on('UPDATE budget_jars', () => {
        updated = true;
        return [];
      });
    const service = new BudgetJarsService(db);

    await expect(service.remove(USER, JAR, 1)).rejects.toMatchObject({
      code: 'SYNC_CONFLICT',
    });
    expect(updated).toBe(false);
  });

  it('xoá mềm với rev đúng thì chạy UPDATE', async () => {
    const db = new FakeDatabase()
      .on('WHERE j.id = $1 AND j.user_id = $2', [jarRow({ rev: 3 })])
      .on('UPDATE budget_jars', []);
    const service = new BudgetJarsService(db);

    await expect(service.remove(USER, JAR, 4)).resolves.toBeUndefined();
  });
});
