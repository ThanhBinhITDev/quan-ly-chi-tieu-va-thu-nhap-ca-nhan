import { describe, expect, it } from 'vitest';

import { PhotoNotesService } from '../src/modules/photo-notes/photo-notes.service.js';
import { FakeDatabase } from './fake-database.js';

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '99999999-9999-4999-8999-999999999999';
const PHOTO = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const TX = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

/** JPEG 3 byte: đủ để qua bước kiểm chữ ký tệp. */
const JPEG_B64 = Buffer.from([0xff, 0xd8, 0xff]).toString('base64');
/** PNG 8 byte. */
const PNG_B64 = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).toString(
  'base64',
);

function row(overrides: Record<string, unknown> = {}) {
  return {
    id: PHOTO,
    transaction_id: TX,
    caption: 'Cơm trưa',
    taken_at: '2026-11-21T05:00:00.000Z',
    taken_on: '2026-11-21',
    photo_mime: 'image/jpeg',
    photo_data: Buffer.from([0xff, 0xd8, 0xff]),
    rev: 1,
    created_at: '2026-11-21T05:00:00.000Z',
    updated_at: '2026-11-21T05:00:00.000Z',
    ...overrides,
  };
}

describe('PhotoNotesService.create', () => {
  it('gắn ảnh vào giao dịch của chính mình thì lưu được', async () => {
    const db = new FakeDatabase()
      .on('FROM transactions', [{ id: TX }])
      .on('FROM photo_notes WHERE id = $1', [])
      .on('INSERT INTO photo_notes', [row()]);
    const service = new PhotoNotesService(db);

    const view = await service.create(USER, {
      id: PHOTO,
      transaction_id: TX,
      caption: 'Cơm trưa',
      photo_base64: JPEG_B64,
      photo_mime: 'image/jpeg',
    });

    expect(view.id).toBe(PHOTO);
    expect(view.transaction_id).toBe(TX);
    expect(view.has_photo).toBe(true);
    expect(view.photo_base64).toBe(JPEG_B64);
  });

  it('chặn gắn ảnh vào giao dịch không phải của mình', async () => {
    // Truy vấn kiểm giao dịch lọc theo user_id nên trả rỗng.
    const db = new FakeDatabase().on('FROM transactions', []);
    const service = new PhotoNotesService(db);

    await expect(
      service.create(USER, {
        id: PHOTO,
        transaction_id: TX,
        photo_base64: JPEG_B64,
        photo_mime: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND', field: 'transaction_id' });
  });

  it('chặn ảnh khai báo sai loại so với chữ ký tệp', async () => {
    const db = new FakeDatabase().on('FROM transactions', [{ id: TX }]);
    const service = new PhotoNotesService(db);

    await expect(
      service.create(USER, {
        id: PHOTO,
        transaction_id: TX,
        photo_base64: PNG_B64,
        photo_mime: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION', field: 'photo_mime' });
  });

  it('chặn tệp không phải ảnh', async () => {
    const db = new FakeDatabase().on('FROM transactions', [{ id: TX }]);
    const service = new PhotoNotesService(db);

    await expect(
      service.create(USER, {
        id: PHOTO,
        transaction_id: TX,
        photo_base64: Buffer.from('day khong phai anh').toString('base64'),
        photo_mime: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });

  it('ảnh quá 512KB bị chặn', async () => {
    const db = new FakeDatabase().on('FROM transactions', [{ id: TX }]);
    const service = new PhotoNotesService(db);
    const big = Buffer.concat([
      Buffer.from([0xff, 0xd8, 0xff]),
      Buffer.alloc(513 * 1024, 0),
    ]);

    await expect(
      service.create(USER, {
        id: PHOTO,
        transaction_id: TX,
        photo_base64: big.toString('base64'),
        photo_mime: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION', field: 'photo_base64' });
  });

  it('gửi lại cùng id thì trả bản đã có, không tạo trùng', async () => {
    // Retry sau khi mất mạng là chuyện thường; id do client sinh nên phải
    // idempotent, nếu không mỗi lần retry lại thêm một ảnh.
    const db = new FakeDatabase()
      .on('FROM transactions', [{ id: TX }])
      .on('SELECT user_id FROM photo_notes', [{ user_id: USER }])
      .on('SELECT', [row({ rev: 2 })]);
    const service = new PhotoNotesService(db);

    const view = await service.create(USER, {
      id: PHOTO,
      transaction_id: TX,
      photo_base64: JPEG_B64,
      photo_mime: 'image/jpeg',
    });

    expect(view.rev).toBe(2);
    expect(db.executed.some((sql) => sql.includes('INSERT INTO photo_notes'))).toBe(
      false,
    );
  });

  it('id đã thuộc người khác thì báo FORBIDDEN', async () => {
    const db = new FakeDatabase()
      .on('FROM transactions', [{ id: TX }])
      .on('SELECT user_id FROM photo_notes', [{ user_id: OTHER }]);
    const service = new PhotoNotesService(db);

    await expect(
      service.create(USER, {
        id: PHOTO,
        transaction_id: TX,
        photo_base64: JPEG_B64,
        photo_mime: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('PhotoNotesService.update', () => {
  it('rev lệch thì báo SYNC_CONFLICT kèm dữ liệu server', async () => {
    const db = new FakeDatabase().on('to_jsonb(p)', [
      { rev: 3, payload: { id: PHOTO, caption: 'bản server' } },
    ]);
    const service = new PhotoNotesService(db);

    await expect(
      service.update(USER, PHOTO, { rev: 2, caption: 'bản client' }),
    ).rejects.toMatchObject({
      code: 'SYNC_CONFLICT',
      details: { server_rev: 3 },
    });
  });

  it('không gửi ảnh mới thì giữ nguyên ảnh cũ', async () => {
    const db = new FakeDatabase()
      .on('to_jsonb(p)', [{ rev: 1, payload: {} }])
      .on('UPDATE photo_notes', [row({ rev: 2, caption: 'Đổi ghi chú' })]);
    const service = new PhotoNotesService(db);

    const view = await service.update(USER, PHOTO, {
      rev: 2,
      caption: 'Đổi ghi chú',
    });

    expect(view.caption).toBe('Đổi ghi chú');
    expect(view.has_photo).toBe(true);
  });

  it('gửi ảnh mới thì kiểm chữ ký như lúc tạo', async () => {
    const db = new FakeDatabase().on('to_jsonb(p)', [{ rev: 1, payload: {} }]);
    const service = new PhotoNotesService(db);

    await expect(
      service.update(USER, PHOTO, {
        rev: 2,
        photo_base64: 'khong-phai-anh',
        photo_mime: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'RULE_VIOLATION' });
  });
});

describe('PhotoNotesService.list', () => {
  it('lọc theo giao dịch khi có transaction_id', async () => {
    const db = new FakeDatabase().on('FROM photo_notes', [row()]);
    const service = new PhotoNotesService(db);

    await service.list(USER, { transaction_id: TX });
    expect(db.lastSql).toContain('transaction_id = $2');
  });

  it('danh sách không mang bytes ảnh', async () => {
    const db = new FakeDatabase().on('FROM photo_notes', [row()]);
    const service = new PhotoNotesService(db);

    const { items } = await service.list(USER, {});
    expect(items[0]!.photo_base64).toBeUndefined();
    expect(items[0]!.has_photo).toBe(true);
  });

  it('mặc định 50 dòng, tôn trọng limit client gửi', async () => {
    const db = new FakeDatabase().on('FROM photo_notes', []);
    const service = new PhotoNotesService(db);

    await service.list(USER, {});
    expect(db.lastSql).toContain('LIMIT $2');
  });
});

describe('PhotoNotesService.remove', () => {
  it('ảnh của người khác thì không xoá được', async () => {
    const db = new FakeDatabase().on('UPDATE photo_notes', []);
    const service = new PhotoNotesService(db);

    await expect(service.remove(USER, PHOTO)).rejects.toMatchObject({
      code: 'NOT_FOUND',
    });
  });

  it('xoá mềm: set deleted_at chứ không DELETE', async () => {
    const db = new FakeDatabase().on('UPDATE photo_notes', [{ id: PHOTO }]);
    const service = new PhotoNotesService(db);

    await service.remove(USER, PHOTO);
    expect(db.lastSql).toContain('deleted_at = now()');
    expect(db.executed.some((sql) => sql.includes('DELETE FROM photo_notes'))).toBe(
      false,
    );
  });
});
