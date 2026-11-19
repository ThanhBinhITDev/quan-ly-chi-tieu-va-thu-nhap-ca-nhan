import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type { RegisterDeviceDto } from './device.dto.js';

export interface DeviceRow {
  id: string;
  platform: string;
  push_token: string | null;
  app_version: string | null;
  last_sync_at: string | null;
}

@Injectable()
export class DevicesService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(userId: string): Promise<DeviceRow[]> {
    return this.db.query<DeviceRow>(
      `SELECT id, platform, push_token, app_version, last_sync_at
         FROM devices WHERE user_id = $1 ORDER BY created_at DESC`,
      [userId],
    );
  }

  /** Đăng ký idempotent: cùng id gửi lại thì cập nhật token/phiên bản. */
  async register(userId: string, dto: RegisterDeviceDto): Promise<DeviceRow> {
    const existing = await this.db.one<{ user_id: string }>(
      `SELECT user_id FROM devices WHERE id = $1`,
      [dto.id],
    );
    if (existing && existing.user_id !== userId) {
      throw new ApiError('FORBIDDEN', 'Thiết bị thuộc người dùng khác');
    }

    const row = await this.db.one<DeviceRow>(
      `INSERT INTO devices (id, user_id, platform, push_token, app_version)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (id) DO UPDATE
         SET push_token = COALESCE(EXCLUDED.push_token, devices.push_token),
             app_version = COALESCE(EXCLUDED.app_version, devices.app_version)
       RETURNING id, platform, push_token, app_version, last_sync_at`,
      [dto.id, userId, dto.platform, dto.push_token ?? null, dto.app_version ?? null],
    );
    if (!row) throw new ApiError('INTERNAL', 'Không đăng ký được thiết bị');
    return row;
  }
}
