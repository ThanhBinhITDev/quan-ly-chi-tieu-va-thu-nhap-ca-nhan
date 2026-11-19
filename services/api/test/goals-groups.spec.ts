import { describe, expect, it } from 'vitest';

import { goalProgress, GoalsService } from '../src/modules/goals/goals.service.js';
import { generateInviteCode, GroupsService } from '../src/modules/groups/groups.service.js';
import { minimizeSettlements } from '../src/modules/groups/settlement.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '99999999-9999-4999-8999-999999999999';
const GOAL = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const GROUP = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

describe('goalProgress', () => {
  it('làm tròn 1 chữ số thập phân', () => {
    expect(goalProgress(200_000, 500_000)).toBe(40);
    expect(goalProgress(1, 3)).toBe(33.3);
  });

  it('không vượt 100%', () => {
    expect(goalProgress(900_000, 500_000)).toBe(100);
  });

  it('target = 0 trả 0, không chia cho 0', () => {
    expect(goalProgress(100, 0)).toBe(0);
  });
});

describe('minimizeSettlements', () => {
  it('ghép người nợ nhiều nhất với người nhận nhiều nhất', () => {
    const result = minimizeSettlements([
      { user_id: 'u1', net: 300_000 },
      { user_id: 'u2', net: -100_000 },
      { user_id: 'u3', net: -200_000 },
    ]);
    expect(result).toEqual([
      { from: 'u3', to: 'u1', amount: 200_000 },
      { from: 'u2', to: 'u1', amount: 100_000 },
    ]);
  });

  it('tổng chuyển bằng đúng tổng nợ', () => {
    const result = minimizeSettlements([
      { user_id: 'u1', net: 150_000 },
      { user_id: 'u2', net: -50_000 },
      { user_id: 'u3', net: -100_000 },
    ]);
    const total = result.reduce((sum, s) => sum + s.amount, 0);
    expect(total).toBe(150_000);
  });

  it('tất cả về 0 thì không có giao dịch', () => {
    expect(
      minimizeSettlements([
        { user_id: 'u1', net: 0 },
        { user_id: 'u2', net: 0 },
      ]),
    ).toEqual([]);
  });
});

describe('generateInviteCode', () => {
  it('dài 8 ký tự và không có ký tự dễ nhầm', () => {
    for (let i = 0; i < 50; i += 1) {
      const code = generateInviteCode();
      expect(code).toHaveLength(8);
      expect(code).not.toMatch(/[0O1I]/);
    }
  });
});

describe('GoalsService', () => {
  it('chặn hạn chót ở quá khứ', async () => {
    const service = new GoalsService(new FakeDatabase());
    await expect(
      service.create(USER, {
        id: GOAL,
        name: 'Mua laptop',
        target_amount: 500_000,
        deadline: '2020-01-01',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('saved_amount là số tuyệt đối, gửi lại không cộng lặp', async () => {
    const row = {
      id: GOAL,
      name: 'Mua laptop',
      target_amount: '500000',
      saved_amount: '350000',
      deadline: null,
      icon: null,
      is_completed: false,
      rev: 2,
      updated_at: new Date('2026-11-19T00:00:00Z'),
    };
    const db = new FakeDatabase()
      .on('SELECT rev, to_jsonb(g)', [{ rev: 1, payload: { id: GOAL } }])
      .on('UPDATE goals', [row]);
    const service = new GoalsService(db);

    const goal = await service.update(USER, GOAL, {
      saved_amount: 350_000,
      rev: 2,
    });
    expect(goal.saved_amount).toBe(350_000);
    expect(goal.progress_pct).toBe(70);
  });
});

describe('GroupsService', () => {
  it('chặn chia tiền khi tổng phần chia khác amount', async () => {
    const db = new FakeDatabase().on('FROM group_members', [
      { user_id: USER },
    ]);
    const service = new GroupsService(db);

    await expect(
      service.addExpense(USER, GROUP, {
        id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        amount: 400_000,
        occurred_on: '2026-11-17',
        shares: [
          { user_id: USER, share_amount: 100_000 },
          { user_id: OTHER, share_amount: 100_000 },
        ],
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('chặn chia cho người không thuộc nhóm', async () => {
    const db = new FakeDatabase().on('FROM group_members', [{ user_id: USER }]);
    const service = new GroupsService(db);

    await expect(
      service.addExpense(USER, GROUP, {
        id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        amount: 200_000,
        occurred_on: '2026-11-17',
        shares: [
          { user_id: USER, share_amount: 100_000 },
          { user_id: OTHER, share_amount: 100_000 },
        ],
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('chặn người ngoài nhóm thêm khoản chi', async () => {
    const service = new GroupsService(new FakeDatabase()); // assertMember -> null

    await expect(
      service.addExpense(OTHER, GROUP, {
        id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        amount: 100_000,
        occurred_on: '2026-11-17',
        shares: [{ user_id: OTHER, share_amount: 100_000 }],
      }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('mã mời không tồn tại trả NOT_FOUND, không lộ lý do', async () => {
    const service = new GroupsService(new FakeDatabase());
    await expect(
      service.join(USER, { invite_code: 'KHONGCO1' }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});
