import { describe, expect, it } from 'vitest';

import { ApiError } from '../src/common/errors/api-error.js';
import { CategoriesService } from '../src/modules/categories/categories.service.js';
import { TransactionsService } from '../src/modules/transactions/transactions.service.js';
import { WalletsService } from '../src/modules/wallets/wallets.service.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';
const WALLET = '22222222-2222-4222-8222-222222222222';

/** Dòng ví đầy đủ như `COLUMNS` của WalletsService trả về (có `balance`). */
function walletRow(overrides: Record<string, unknown> = {}) {
  return {
    id: WALLET,
    name: 'Tiền mặt',
    type: 'cash',
    initial_balance: '0',
    balance: '0',
    color: null,
    icon: null,
    is_archived: false,
    rev: 1,
    deleted_at: null,
    ...overrides,
  };
}
const OTHER_WALLET = '33333333-3333-4333-8333-333333333333';
const TX = '44444444-4444-4444-8444-444444444444';

describe('WalletsService', () => {
  it('tạo ví mới khi chưa có', async () => {
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM wallets WHERE id', [])
      .on('count(*)', [{ count: '0' }])
      .on('INSERT INTO wallets', [walletRow()])
      // create() đọc lại sau INSERT để trả cùng shape có `balance`.
      .on('FROM wallets w', [walletRow()]);
    const service = new WalletsService(db);

    const wallet = await service.create(USER, {
      id: WALLET,
      name: 'Tiền mặt',
      type: 'cash',
    });

    expect(wallet.id).toBe(WALLET);
    expect(wallet.initial_balance).toBe(0);
    // Ví mới chưa có giao dịch: số dư bằng số dư khai báo ban đầu.
    expect(wallet.balance).toBe(0);
  });

  it('gửi lại cùng id thì trả ví cũ, không tạo trùng', async () => {
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM wallets WHERE id', [
        { id: WALLET, user_id: USER },
      ])
      .on('FROM wallets w', [walletRow()]);
    const service = new WalletsService(db);

    await expect(
      service.create(USER, { id: WALLET, name: 'Khác', type: 'cash' }),
    ).resolves.toMatchObject({ id: WALLET });
  });

  it('chặn ví thứ 4 ở gói miễn phí', async () => {
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM wallets WHERE id', [])
      .on('count(*)', [{ count: '3' }]);
    const service = new WalletsService(db);

    await expect(
      service.create(USER, { id: WALLET, name: 'Ví 4', type: 'bank' }),
    ).rejects.toMatchObject({ code: 'PLAN_LIMIT' });
  });

  it('sửa với rev sai trả SYNC_CONFLICT', async () => {
    const db = new FakeDatabase().on('FROM wallets w', [
      walletRow({ rev: 5 }),
    ]);
    const service = new WalletsService(db);

    const error = await service
      .update(USER, WALLET, { name: 'Mới', rev: 3 })
      .catch((e: unknown) => e);

    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).code).toBe('SYNC_CONFLICT');
  });

  it('xoá mềm ví: set deleted_at, tăng rev, trả bản ghi đã xoá', async () => {
    const deleted = walletRow({
      rev: 2,
      deleted_at: '2026-11-20T00:00:00.000Z',
    });
    const db = new FakeDatabase();
    // Lần đọc đầu (còn sống) thấy rev 1; sau UPDATE đọc lại thấy bản đã xoá.
    db.query = async <T,>(sql: string) => {
      db.executed.push(sql);
      if (sql.includes('UPDATE wallets')) return [] as T[];
      if (sql.includes('FROM wallets w')) {
        return [sql.includes('w.deleted_at IS NULL') ? walletRow({ rev: 1 }) : deleted] as T[];
      }
      return [] as T[];
    };
    const service = new WalletsService(db);

    const row = await service.remove(USER, WALLET, 2);

    const update = db.executed.find((sql) => sql.includes('UPDATE wallets'));
    expect(update).toContain('deleted_at = now()');
    expect(row.rev).toBe(2);
    expect(row.deleted_at).toBe('2026-11-20T00:00:00.000Z');
  });

  it('xoá ví với rev sai trả SYNC_CONFLICT', async () => {
    const db = new FakeDatabase().on('FROM wallets w', [walletRow({ rev: 5 })]);
    const service = new WalletsService(db);

    await expect(service.remove(USER, WALLET, 2)).rejects.toMatchObject({
      code: 'SYNC_CONFLICT',
    });
  });

  it('biểu thức số dư bỏ giao dịch đã xoá mềm', async () => {
    const db = new FakeDatabase().on('FROM wallets w', [walletRow()]);
    const service = new WalletsService(db);

    await service.list(USER);

    // Nếu quên điều kiện này thì giao dịch đã xoá vẫn bị cộng/trừ vào số dư.
    expect(db.lastSql).toContain('t.deleted_at IS NULL');
    expect(db.lastSql).toContain("t.type = 'transfer'");
  });

  it('tổng hợp số dư: cộng theo ví và theo loại, bỏ ví đã xoá', async () => {
    const db = new FakeDatabase().on('FROM wallets w', [
      walletRow({ id: WALLET, type: 'cash', balance: '150000' }),
      walletRow({ id: OTHER_WALLET, type: 'bank', balance: '-50000' }),
    ]);
    const service = new WalletsService(db);

    const summary = await service.balances(USER);

    expect(summary.wallets).toHaveLength(2);
    expect(summary.total_balance).toBe(100000);
    expect(summary.by_type).toEqual({ cash: 150000, bank: -50000 });
    // Câu SQL mặc định phải lọc ví đã xoá mềm.
    expect(db.lastSql).toContain('deleted_at IS NULL');
  });
});

describe('CategoriesService', () => {
  const CATEGORY = 'aaaa1111-1111-4111-8111-111111111111';

  it('xoá mềm danh mục riêng của người dùng', async () => {
    const db = new FakeDatabase()
      .on('FROM categories', [
        {
          id: CATEGORY,
          user_id: USER,
          name: 'Cà phê',
          type: 'expense',
          icon: null,
          color: null,
          parent_id: null,
          is_system: false,
          sort_order: 0,
          rev: 1,
          deleted_at: null,
        },
      ])
      .on('UPDATE categories', []);
    const service = new CategoriesService(db);

    const row = await service.remove(USER, CATEGORY, 2);
    expect(row.id).toBe(CATEGORY);
  });

  it('xoá danh mục với rev sai trả SYNC_CONFLICT', async () => {
    const db = new FakeDatabase().on('FROM categories', [
      {
        id: CATEGORY,
        user_id: USER,
        name: 'Cà phê',
        type: 'expense',
        icon: null,
        color: null,
        parent_id: null,
        is_system: false,
        sort_order: 0,
        rev: 5,
        deleted_at: null,
      },
    ]);
    const service = new CategoriesService(db);

    await expect(service.remove(USER, CATEGORY, 2)).rejects.toMatchObject({
      code: 'SYNC_CONFLICT',
    });
  });

  it('mặc định không trả danh mục đã xoá mềm', async () => {
    const db = new FakeDatabase().on('FROM categories', []);
    const service = new CategoriesService(db);

    await service.list(USER);
    expect(db.lastSql).toContain('deleted_at IS NULL');

    await service.list(USER, undefined, true);
    expect(db.lastSql).not.toContain('deleted_at IS NULL');
  });

  it('không cho xoá danh mục hệ thống', async () => {
    const db = new FakeDatabase().on('FROM categories', [
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
        deleted_at: null,
      },
    ]);
    const service = new CategoriesService(db);

    await expect(service.remove(USER, CATEGORY)).rejects.toMatchObject({
      code: 'FORBIDDEN',
    });
  });
});

describe('TransactionsService', () => {
  it('chặn chuyển ví sang chính nó', async () => {
    const service = new TransactionsService(new FakeDatabase());

    await expect(
      service.create(USER, {
        id: TX,
        wallet_id: WALLET,
        to_wallet_id: WALLET,
        type: 'transfer',
        amount: 50_000,
        occurred_at: '2026-11-19T10:00:00Z',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('chặn chuyển ví thiếu ví nhận', async () => {
    const service = new TransactionsService(new FakeDatabase());

    await expect(
      service.create(USER, {
        id: TX,
        wallet_id: WALLET,
        type: 'transfer',
        amount: 50_000,
        occurred_at: '2026-11-19T10:00:00Z',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('chặn ví không thuộc người dùng', async () => {
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM transactions WHERE id', [])
      .on('SELECT id FROM wallets', []);
    const service = new TransactionsService(db);

    await expect(
      service.create(USER, {
        id: TX,
        wallet_id: OTHER_WALLET,
        type: 'expense',
        amount: 35_000,
        occurred_at: '2026-11-19T10:00:00Z',
      }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('tạo giao dịch chi thành công và amount là số', async () => {
    const row = {
      id: TX,
      wallet_id: WALLET,
      category_id: null,
      type: 'expense',
      amount: '35000',
      to_wallet_id: null,
      note: 'Ăn trưa',
      occurred_at: new Date('2026-11-19T10:00:00Z'),
      occurred_on: '2026-11-19',
      source: 'manual',
      rev: 1,
      created_at: new Date('2026-11-19T10:00:00Z'),
      updated_at: new Date('2026-11-19T10:00:00Z'),
      deleted_at: null,
    };
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM transactions WHERE id', [])
      .on('SELECT id FROM wallets', [{ id: WALLET }])
      .on('INSERT INTO transactions', [row]);
    const service = new TransactionsService(db);

    const created = await service.create(USER, {
      id: TX,
      wallet_id: WALLET,
      type: 'expense',
      amount: 35_000,
      note: 'Ăn trưa',
      occurred_at: '2026-11-19T10:00:00Z',
    });

    expect(created.amount).toBe(35_000);
    expect(created.occurred_at).toBe('2026-11-19T10:00:00.000Z');
  });

  it('danh sách lọc bỏ bản ghi đã xóa mềm', async () => {
    const db = new FakeDatabase().on('FROM transactions', [
      {
        id: TX,
        wallet_id: WALLET,
        category_id: null,
        type: 'expense',
        amount: '10000',
        to_wallet_id: null,
        note: null,
        occurred_at: new Date('2026-11-19T10:00:00Z'),
        occurred_on: '2026-11-19',
        source: 'manual',
        rev: 1,
        created_at: new Date('2026-11-19T10:00:00Z'),
        updated_at: new Date('2026-11-19T10:00:00Z'),
        deleted_at: null,
      },
    ]);
    const service = new TransactionsService(db);

    const rows = await service.list(USER, { limit: 10 });
    expect(rows).toHaveLength(1);
  });
});
