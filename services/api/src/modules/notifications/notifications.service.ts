import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';

interface NotificationRow {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  read_at: Date | null;
  created_at: Date;
}

export interface NotificationItem {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  read_at: string | null;
  created_at: string;
}

export interface NotificationList {
  items: NotificationItem[];
  unread_count: number;
}

const COLUMNS = 'id, type, title, body, data, read_at, created_at';

function toItem(row: NotificationRow): NotificationItem {
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    body: row.body,
    data: row.data,
    read_at: row.read_at ? row.read_at.toISOString() : null,
    created_at: row.created_at.toISOString(),
  };
}

/**
 * Hộp thư thông báo chỉ đọc từ phía client.
 *
 * Không có hàm `create` ở đây: thông báo do job phía worker sinh ra, không do
 * người dùng tự tạo. Cho client ghi là mở đường tự tạo thông báo giả, và RLS
 * cũng đã chặn INSERT.
 */
@Injectable()
export class NotificationsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(
    userId: string,
    options: { limit?: number; unreadOnly?: boolean } = {},
  ): Promise<NotificationList> {
    const limit = options.limit ?? 30;
    const rows = await this.db.query<NotificationRow>(
      `SELECT ${COLUMNS}
         FROM notifications
        WHERE user_id = $1
          ${options.unreadOnly ? 'AND read_at IS NULL' : ''}
        ORDER BY created_at DESC
        LIMIT $2`,
      [userId, limit],
    );
    return {
      items: rows.map(toItem),
      unread_count: await this.unreadCount(userId),
    };
  }

  /**
   * Số tin chưa đọc. `unread_count` luôn tính trên toàn hộp thư, không phải
   * trên trang vừa trả về — badge chuông phải đúng dù client chỉ tải 30 tin.
   */
  async unreadCount(userId: string): Promise<number> {
    const row = await this.db.one<{ count: string }>(
      `SELECT count(*)::text AS count
         FROM notifications
        WHERE user_id = $1 AND read_at IS NULL`,
      [userId],
    );
    return row ? Number(row.count) : 0;
  }

  /** Đánh dấu một tin đã đọc. Tin của người khác trả NOT_FOUND, không 403. */
  async markRead(userId: string, id: string): Promise<NotificationItem> {
    const row = await this.db.one<NotificationRow>(
      `UPDATE notifications
          SET read_at = COALESCE(read_at, now())
        WHERE id = $1 AND user_id = $2
        RETURNING ${COLUMNS}`,
      [id, userId],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy thông báo');
    return toItem(row);
  }

  /** Đánh dấu tất cả đã đọc. Trả số dòng vừa đổi để client cập nhật badge. */
  async markAllRead(userId: string): Promise<{ updated: number }> {
    const rows = await this.db.query<{ id: string }>(
      `UPDATE notifications
          SET read_at = now()
        WHERE user_id = $1 AND read_at IS NULL
        RETURNING id`,
      [userId],
    );
    return { updated: rows.length };
  }
}
