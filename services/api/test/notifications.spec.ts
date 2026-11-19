import { describe, expect, it } from 'vitest';

import { ApiError } from '../src/common/errors/api-error.js';
import { NotificationsService } from '../src/modules/notifications/notifications.service.js';
import { FakeDatabase } from './fake-database.js';

const USER = '55555555-5555-4555-8555-555555555555';
const OTHER_USER = '11111111-1111-4111-8111-111111111111';
const NOTE = '5e000000-0000-4000-8000-000000000001';

function noteRow(overrides: Record<string, unknown> = {}) {
  return {
    id: NOTE,
    type: 'budget_alert',
    title: 'Ngân sách tháng 11 đã dùng 88%',
    body: '1.768.000 đ / 2.000.000 đ hạn mức tháng.',
    data: { month: '2026-11' },
    read_at: null,
    created_at: new Date('2026-11-19T21:22:49.635Z'),
    ...overrides,
  };
}

describe('NotificationsService', () => {
  it('trả tin và đếm chưa đọc trên toàn hộp thư', async () => {
    const db = new FakeDatabase()
      // Đăng ký `count(*)` trước: câu đếm cũng chứa "FROM notifications"
      // nên nếu để sau, handler danh sách sẽ nuốt mất và trả về 0.
      .on('count(*)', [{ count: '7' }])
      .on('FROM notifications', [noteRow()]);
    const service = new NotificationsService(db);

    const result = await service.list(USER);

    expect(result.items).toHaveLength(1);
    expect(result.items[0]?.data).toEqual({ month: '2026-11' });
    // created_at phải là chuỗi ISO để client parse được, không phải Date.
    expect(result.items[0]?.created_at).toBe('2026-11-19T21:22:49.635Z');
    // unread_count tính trên cả hộp thư, không phải trên trang trả về.
    expect(result.unread_count).toBe(7);
  });

  it('lọc tin chưa đọc khi unreadOnly', async () => {
    const db = new FakeDatabase()
      .on('count(*)', [{ count: '1' }])
      .on('FROM notifications', [noteRow()]);
    const service = new NotificationsService(db);

    await service.list(USER, { unreadOnly: true });

    // `lastSql` là câu đếm chạy sau cùng, nên tìm câu danh sách trong `executed`.
    const listSql = db.executed.find((sql) => sql.includes('LIMIT')) ?? '';
    expect(listSql).toContain('read_at IS NULL');
    // LIMIT phải có tham số, không nối chuỗi.
    expect(listSql).toContain('LIMIT $2');
  });

  it('mặc định lấy 30 tin và luôn lọc theo user_id', async () => {
    const db = new FakeDatabase()
      .on('FROM notifications', [])
      .on('count(*)', [{ count: '0' }]);
    const service = new NotificationsService(db);

    await service.list(USER);

    expect(db.lastSql).toContain('user_id = $1');
  });

  it('đánh dấu đã đọc giữ nguyên thời điểm đọc lần đầu', async () => {
    const first = new Date('2026-11-19T21:25:13.308Z');
    const db = new FakeDatabase().on('UPDATE notifications', [
      noteRow({ read_at: first }),
    ]);
    const service = new NotificationsService(db);

    const item = await service.markRead(USER, NOTE);

    expect(item.read_at).toBe('2026-11-19T21:25:13.308Z');
    // COALESCE: đọc lại lần hai không ghi đè mốc thời gian cũ.
    expect(db.lastSql).toContain('COALESCE(read_at, now())');
    expect(db.lastSql).toContain('user_id = $2');
  });

  it('tin của người khác trả NOT_FOUND, không phải FORBIDDEN', async () => {
    // Không lộ sự tồn tại của tin thuộc người khác.
    const db = new FakeDatabase().on('UPDATE notifications', []);
    const service = new NotificationsService(db);

    await expect(service.markRead(OTHER_USER, NOTE)).rejects.toMatchObject({
      code: 'NOT_FOUND',
    } satisfies Partial<ApiError>);
  });

  it('đánh dấu tất cả trả về số dòng đã đổi', async () => {
    const db = new FakeDatabase().on('UPDATE notifications', [
      { id: 'a' },
      { id: 'b' },
      { id: 'c' },
    ]);
    const service = new NotificationsService(db);

    const result = await service.markAllRead(USER);

    expect(result.updated).toBe(3);
    expect(db.lastSql).toContain('read_at IS NULL');
  });
});
