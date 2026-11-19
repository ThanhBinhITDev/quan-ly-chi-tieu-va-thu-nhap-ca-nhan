import { Inject, Injectable } from '@nestjs/common';

import type { AuthUser } from '../../common/auth/supabase-auth.service.js';
import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type { UpdateMeDto } from './me.dto.js';

export interface MeRow {
  id: string;
  email: string | null;
  phone: string | null;
  display_name: string;
  username: string | null;
  has_avatar: boolean;
  avatar_updated_at: string | null;
  plan: string;
  plan_expires_at: string | null;
  currency: string;
  timezone: string;
  onboarded_at: string | null;
  created_at: string;
}

/**
 * `avatar_data` được thay bằng cờ `has_avatar`: client không cần nhận vài trăm
 * KB base64 trong mỗi lần mở app. Ảnh lấy riêng qua `GET /v1/me/avatar`.
 */
const COLUMNS = `id, email, phone, display_name, username,
       (avatar_data IS NOT NULL) AS has_avatar, avatar_updated_at,
       plan, plan_expires_at, currency, timezone, onboarded_at, created_at`;

const AVATAR_MAX_BYTES = 262_144;
const AVATAR_MIMES = ['image/jpeg', 'image/png', 'image/webp'] as const;

@Injectable()
export class MeService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /**
   * Chứng minh token đã xác thực bằng cách trả hồ sơ người dùng.
   * Nếu chưa có dòng `users` (đăng ký qua Supabase Auth nhưng chưa bootstrap),
   * tạo ngay — mọi bảng khác đều có khoá ngoại tới `users(id)`.
   */
  async ensure(user: AuthUser): Promise<MeRow> {
    const existing = await this.db.one<MeRow>(
      `SELECT ${COLUMNS} FROM users WHERE id = $1 AND deleted_at IS NULL`,
      [user.id],
    );
    if (existing) return normalize(existing);

    const email = user.email ?? null;
    const phone = user.phone ?? null;
    // `users_contact` bắt buộc có ít nhất email hoặc phone. Token Supabase
    // không kèm cả hai thì trả lỗi rõ ràng, không để DB ném 500.
    if (!email && !phone) {
      throw new ApiError(
        'VALIDATION_FAILED',
        'Token không có email hoặc số điện thoại để tạo hồ sơ',
      );
    }
    const created = await this.db.one<MeRow>(
      `INSERT INTO users (id, email, phone, display_name)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (id) DO UPDATE SET deleted_at = NULL
       RETURNING ${COLUMNS}`,
      [user.id, email, phone, displayNameFromEmail(email, phone)],
    );
    if (!created) throw new ApiError('INTERNAL', 'Không tạo được hồ sơ');
    return normalize(created);
  }

  async update(userId: string, dto: UpdateMeDto): Promise<MeRow> {
    // `username` cần báo lỗi rõ khi trùng, nên tách khỏi câu UPDATE chung:
    // nếu gộp, Postgres ném lỗi unique constraint khó dịch thành thông báo.
    if (dto.username !== undefined) {
      const normalized = dto.username.trim().toLowerCase();
      const taken = await this.db.one<{ id: string }>(
        `SELECT id FROM users
          WHERE username = $1 AND deleted_at IS NULL AND id <> $2`,
        [normalized, userId],
      );
      if (taken) {
        throw new ApiError('RULE_VIOLATION', 'Tên người dùng này đã có người dùng');
      }
    }

    const row = await this.db.one<MeRow>(
      `UPDATE users
          SET display_name = COALESCE($2, display_name),
              currency = COALESCE($3, currency),
              timezone = COALESCE($4, timezone),
              username = COALESCE($5, username)
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING ${COLUMNS}`,
      [
        userId,
        dto.display_name ?? null,
        dto.currency ?? null,
        dto.timezone ?? null,
        dto.username === undefined ? null : dto.username.trim().toLowerCase(),
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy hồ sơ');
    return normalize(row);
  }

  /** Lưu ảnh đại diện đã cắt sẵn. Ảnh nhỏ nên nhận base64 trong JSON. */
  async putAvatar(
    userId: string,
    mime: string,
    base64: string,
  ): Promise<MeRow> {
    if (!AVATAR_MIMES.includes(mime as (typeof AVATAR_MIMES)[number])) {
      throw new ApiError(
        'VALIDATION_FAILED',
        `Ảnh phải là ${AVATAR_MIMES.join(', ')}`,
      );
    }
    let buffer: Buffer;
    try {
      buffer = Buffer.from(base64, 'base64');
    } catch {
      throw new ApiError('VALIDATION_FAILED', 'Dữ liệu ảnh không hợp lệ');
    }
    if (buffer.length === 0) {
      throw new ApiError('VALIDATION_FAILED', 'Dữ liệu ảnh rỗng');
    }
    if (buffer.length > AVATAR_MAX_BYTES) {
      throw new ApiError(
        'VALIDATION_FAILED',
        'Ảnh vượt 256 KB sau khi cắt. Kéo nhỏ vùng chọn rồi thử lại.',
      );
    }
    // Kiểm chữ ký tệp: đừng tin `mime` do client khai. Một tệp HTML khai là
    // image/png mà được phục vụ lại nguyên content-type sẽ thành XSS.
    if (!looksLikeImage(buffer, mime)) {
      throw new ApiError(
        'VALIDATION_FAILED',
        'Nội dung tệp không khớp định dạng ảnh đã khai',
      );
    }

    const row = await this.db.one<MeRow>(
      `UPDATE users
          SET avatar_mime = $2,
              avatar_data = $3,
              avatar_updated_at = now()
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING ${COLUMNS}`,
      [userId, mime, buffer],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy hồ sơ');
    return normalize(row);
  }

  async getAvatar(
    userId: string,
  ): Promise<{ mime: string; data: Buffer; etag: string } | null> {
    const row = await this.db.one<{
      avatar_mime: string;
      avatar_data: Buffer;
      avatar_updated_at: Date | string;
    }>(
      `SELECT avatar_mime, avatar_data, avatar_updated_at
         FROM users
        WHERE id = $1 AND deleted_at IS NULL AND avatar_data IS NOT NULL`,
      [userId],
    );
    if (!row) return null;
    const updated = row.avatar_updated_at;
    // ETag phải là chuỗi không dấu cách (RFC 7232 dùng dấu cách làm dấu phân
    // tách trong danh sách entity-tag). Dùng epoch ms của lần đổi ảnh.
    const etag =
      updated instanceof Date
        ? String(updated.getTime())
        : String(new Date(updated).getTime());
    return { mime: row.avatar_mime, data: row.avatar_data, etag };
  }

  async removeAvatar(userId: string): Promise<MeRow> {
    const row = await this.db.one<MeRow>(
      `UPDATE users
          SET avatar_mime = NULL, avatar_data = NULL, avatar_updated_at = now()
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING ${COLUMNS}`,
      [userId],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy hồ sơ');
    return normalize(row);
  }
}

/** Đuôi tệp của từng định dạng ảnh được chấp nhận (magic bytes). */
function looksLikeImage(buffer: Buffer, mime: string): boolean {
  if (buffer.length < 12) return false;
  switch (mime) {
    case 'image/jpeg':
      return buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
    case 'image/png':
      return (
        buffer[0] === 0x89 &&
        buffer[1] === 0x50 &&
        buffer[2] === 0x4e &&
        buffer[3] === 0x47
      );
    case 'image/webp':
      return (
        buffer.toString('ascii', 0, 4) === 'RIFF' &&
        buffer.toString('ascii', 8, 12) === 'WEBP'
      );
    default:
      return false;
  }
}

function displayNameFromEmail(email: string | null, phone: string | null): string {
  if (email) {
    const local = email.split('@')[0];
    if (local.length > 0) return local.slice(0, 60);
  }
  if (phone) return phone.slice(0, 60);
  return 'Người dùng';
}

/** `pg` trả cột timestamptz dưới dạng `Date`; JSON hoá `Date` ra chuỗi RFC
 * 2822 ("Thu Nov 19 2026...") — sai lệch với hợp đồng API (ISO 8601). Ép về
 * ISO ở một chỗ duy nhất thay vì để client tự đoán định dạng. */
function iso(value: unknown): string | null {
  if (value == null) return null;
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

function normalize(row: MeRow): MeRow {
  return {
    ...row,
    email: row.email ?? null,
    phone: row.phone ?? null,
    username: row.username ?? null,
    has_avatar: Boolean(row.has_avatar),
    avatar_updated_at: iso(row.avatar_updated_at),
    plan_expires_at: iso(row.plan_expires_at),
    onboarded_at: iso(row.onboarded_at),
    created_at: iso(row.created_at) ?? new Date().toISOString(),
  };
}
