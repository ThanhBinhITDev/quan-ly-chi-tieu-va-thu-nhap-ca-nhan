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
  plan: string;
  plan_expires_at: string | null;
  currency: string;
  timezone: string;
  onboarded_at: string | null;
  created_at: string;
}

const COLUMNS = `id, email, phone, display_name, plan, plan_expires_at,
       currency, timezone, onboarded_at, created_at`;

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
    if (!email && !user.id) {
      throw new ApiError('VALIDATION_FAILED', 'Thiếu email để tạo hồ sơ');
    }
    const created = await this.db.one<MeRow>(
      `INSERT INTO users (id, email, display_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (id) DO UPDATE SET deleted_at = NULL
       RETURNING ${COLUMNS}`,
      [user.id, email, displayNameFromEmail(email)],
    );
    if (!created) throw new ApiError('INTERNAL', 'Không tạo được hồ sơ');
    return normalize(created);
  }

  async update(userId: string, dto: UpdateMeDto): Promise<MeRow> {
    const row = await this.db.one<MeRow>(
      `UPDATE users
          SET display_name = COALESCE($2, display_name),
              currency = COALESCE($3, currency),
              timezone = COALESCE($4, timezone),
              plan = COALESCE($5, plan)
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING ${COLUMNS}`,
      [
        userId,
        dto.display_name ?? null,
        dto.currency ?? null,
        dto.timezone ?? null,
        dto.plan ?? null,
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy hồ sơ');
    return normalize(row);
  }
}

function displayNameFromEmail(email: string | null): string {
  if (!email) return 'Người dùng';
  const local = email.split('@')[0];
  return local.length > 0 ? local.slice(0, 60) : 'Người dùng';
}

function normalize(row: MeRow): MeRow {
  return {
    ...row,
    email: row.email ?? null,
    phone: row.phone ?? null,
    plan_expires_at: row.plan_expires_at ? String(row.plan_expires_at) : null,
    onboarded_at: row.onboarded_at ? String(row.onboarded_at) : null,
    created_at: String(row.created_at),
  };
}
