import { describe, expect, it } from 'vitest';

import { ApiError } from '../src/common/errors/api-error.js';
import { TransactionsService } from '../src/modules/transactions/transactions.service.js';
import { WalletsService } from '../src/modules/wallets/wallets.service.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';
const WALLET = '22222222-2222-4222-8222-222222222222';
const OTHER_WALLET = '33333333-3333-4333-8333-333333333333';
const TX = '44444444-4444-4444-8444-444444444444';

describe('WalletsService', () => {
  it('tạo ví mới khi chưa có', async () => {
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM wallets WHERE id', [])
      .on('count(*)', [{ count: '0' }])
      .on('INSERT INTO wallets', [
        {
          id: WALLET,
          name: 'Tiền mặt',
          type: 'cash',
          initial_balance: '0',
          color: null,
          icon: null,
          is_archived: false,
          rev: 1,
        },
      ]);
    const service = new WalletsService(db);

    const wallet = await service.create(USER, {
      id: WALLET,
      name: 'Tiền mặt',
      type: 'cash',
    });

    expect(wallet.id).toBe(WALLET);
    expect(wallet.initial_balance).toBe(0);
  });

  it('gửi lại cùng id thì trả ví cũ, không tạo trùng', async () => {
    const db = new FakeDatabase()
      .on('SELECT id, user_id FROM wallets WHERE id', [
        { id: WALLET, user_id: USER },
      ])
      .on('SELECT id, name, type', [
        {
          id: WALLET,
          name: 'Tiền mặt',
          type: 'cash',
          initial_balance: '0',
          color: null,
          icon: null,
          is_archived: false,
          rev: 1,
        },
      ]);
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
    const db = new FakeDatabase().on('SELECT id, name, type', [
      {
        id: WALLET,
        name: 'Tiền mặt',
        type: 'cash',
        initial_balance: '0',
        color: null,
        icon: null,
        is_archived: false,
        rev: 5,
      },
    ]);
    const service = new WalletsService(db);

    const error = await service
      .update(USER, WALLET, { name: 'Mới', rev: 3 })
      .catch((e: unknown) => e);

    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).code).toBe('SYNC_CONFLICT');
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
