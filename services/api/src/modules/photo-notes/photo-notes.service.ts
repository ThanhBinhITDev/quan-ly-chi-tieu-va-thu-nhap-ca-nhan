import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type {
  CreatePhotoNoteDto,
  ListPhotoNotesQuery,
  UpdatePhotoNoteDto,
} from './photo-note.dto.js';

export interface PhotoNoteRow {
  id: string;
  transaction_id: string;
  caption: string | null;
  taken_at: Date | string;
  taken_on: string;
  photo_mime: string;
  photo_data?: Buffer | null;
  rev: number;
  created_at: Date | string;
  updated_at: Date | string;
}

export interface PhotoNoteView {
  id: string;
  transaction_id: string;
  caption: string | null;
  taken_at: string;
  taken_on: string;
  /** Có ảnh hay không; danh sách không mang bytes. */
  has_photo: boolean;
  photo_mime: string | null;
  /** Chỉ có ở `GET /v1/photo-notes/:id`. */
  photo_base64?: string | null;
  rev: number;
  created_at: string;
  updated_at: string;
}

/** Danh sách chỉ trả cờ, không trả bytes: 50 dòng × 512KB là quá nặng. */
const LIST_COLUMNS = `id, transaction_id, caption, taken_at, taken_on,
       photo_mime, rev, created_at, updated_at`;

const DETAIL_COLUMNS = `${LIST_COLUMNS}, photo_data`;

const PHOTO_MAX_BYTES = 512 * 1024;

@Injectable()
export class PhotoNotesService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /** Dòng thời gian ảnh của một người, mới nhất trước. */
  async list(
    userId: string,
    query: ListPhotoNotesQuery,
  ): Promise<{ items: PhotoNoteView[] }> {
    const limit = query.limit ?? 50;
    const params: unknown[] = [userId];
    const filters = ['user_id = $1', 'deleted_at IS NULL'];

    if (query.transaction_id) {
      params.push(query.transaction_id);
      filters.push(`transaction_id = $${params.length}`);
    }
    if (query.before) {
      params.push(query.before);
      filters.push(`taken_at < $${params.length}`);
    }

    params.push(limit);
    const rows = await this.db.query<PhotoNoteRow>(
      `SELECT ${LIST_COLUMNS}
         FROM photo_notes
        WHERE ${filters.join(' AND ')}
        ORDER BY taken_at DESC, id DESC
        LIMIT $${params.length}`,
      params,
    );
    return { items: rows.map(toListView) };
  }

  /** Chi tiết một ảnh, kèm bytes để hiển thị. */
  async findOne(userId: string, id: string): Promise<PhotoNoteView> {
    const row = await this.db.one<PhotoNoteRow>(
      `SELECT ${DETAIL_COLUMNS}
         FROM photo_notes
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [id, userId],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ảnh');
    return toDetailView(row);
  }

  async create(
    userId: string,
    dto: CreatePhotoNoteDto,
  ): Promise<PhotoNoteView> {
    // Ảnh phải thuộc giao dịch của chính người dùng này; nếu không sẽ gắn
    // được ảnh vào khoản chi của người khác.
    await this.assertOwnTransaction(userId, dto.transaction_id);

    const photo = parsePhoto(dto.photo_base64, dto.photo_mime);

    const existing = await this.db.one<{ user_id: string }>(
      `SELECT user_id FROM photo_notes WHERE id = $1`,
      [dto.id],
    );
    if (existing) {
      if (existing.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Ảnh thuộc người dùng khác');
      }
      // Gửi lại cùng id (retry sau khi mất mạng): trả bản đã có thay vì tạo
      // trùng. Đây là lý do `id` do client sinh.
      return this.findOne(userId, dto.id);
    }

    const row = await this.db.one<PhotoNoteRow>(
      `INSERT INTO photo_notes
         (id, user_id, transaction_id, caption, taken_at, photo_mime, photo_data)
       VALUES ($1, $2, $3, $4, COALESCE($5::timestamptz, now()), $6, $7)
       RETURNING ${DETAIL_COLUMNS}`,
      [
        dto.id,
        userId,
        dto.transaction_id,
        dto.caption ?? null,
        dto.taken_at ?? null,
        photo.mime,
        photo.data,
      ],
    );
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được ảnh');
    return toDetailView(row);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdatePhotoNoteDto,
  ): Promise<PhotoNoteView> {
    const current = await this.db.one<{ rev: number; payload: unknown }>(
      `SELECT rev, to_jsonb(p) AS payload
         FROM photo_notes p
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [id, userId],
    );
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy ảnh');
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current.payload },
      });
    }

    // Chỉ kiểm ảnh khi client thật sự gửi ảnh mới.
    const photo =
      dto.photo_base64 || dto.photo_mime
        ? parsePhoto(dto.photo_base64, dto.photo_mime)
        : null;

    const row = await this.db.one<PhotoNoteRow>(
      `UPDATE photo_notes
          SET caption = COALESCE($3, caption),
              taken_at = COALESCE($4::timestamptz, taken_at),
              photo_mime = COALESCE($5, photo_mime),
              photo_data = COALESCE($6, photo_data),
              rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
        RETURNING ${DETAIL_COLUMNS}`,
      [
        id,
        userId,
        dto.caption ?? null,
        dto.taken_at ?? null,
        photo?.mime ?? null,
        photo?.data ?? null,
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ảnh');
    return toDetailView(row);
  }

  /** Xoá mềm; controller trả 204. */
  async remove(userId: string, id: string): Promise<void> {
    const row = await this.db.one<{ id: string }>(
      `UPDATE photo_notes
          SET deleted_at = now(), rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
        RETURNING id`,
      [id, userId],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy ảnh');
  }

  private async assertOwnTransaction(
    userId: string,
    transactionId: string,
  ): Promise<void> {
    const tx = await this.db.one<{ id: string }>(
      `SELECT id FROM transactions
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [transactionId, userId],
    );
    if (!tx) {
      throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch để gắn ảnh', {
        field: 'transaction_id',
      });
    }
  }
}

function parsePhoto(
  photoBase64?: string,
  photoMime?: string,
): { data: Buffer; mime: string } {
  if (!photoBase64 || !photoMime) {
    throw new ApiError('RULE_VIOLATION', 'Ảnh cần cả dữ liệu và loại ảnh', {
      field: 'photo_base64',
    });
  }
  const data = Buffer.from(photoBase64, 'base64');
  if (data.length === 0 || data.length > PHOTO_MAX_BYTES) {
    throw new ApiError('RULE_VIOLATION', 'Ảnh tối đa 512KB', {
      field: 'photo_base64',
    });
  }
  const sniffed = sniffImageMime(data);
  if (sniffed === null) {
    throw new ApiError(
      'RULE_VIOLATION',
      'Tệp đính kèm không phải ảnh JPEG/PNG/WebP',
      { field: 'photo_base64' },
    );
  }
  if (sniffed !== photoMime) {
    throw new ApiError(
      'RULE_VIOLATION',
      `Ảnh là ${sniffed} nhưng khai báo ${photoMime}`,
      { field: 'photo_mime' },
    );
  }
  return { data, mime: photoMime };
}

/** `Buffer.from(..., 'base64')` không ném lỗi: chuỗi rác chỉ bị cắt ký tự lạ,
 * nên phải kiểm chữ ký tệp mới biết đúng là ảnh. */
function sniffImageMime(data: Buffer): string | null {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    data.length >= 8 &&
    data[0] === 0x89 &&
    data[1] === 0x50 &&
    data[2] === 0x4e &&
    data[3] === 0x47
  ) {
    return 'image/png';
  }
  if (
    data.length >= 12 &&
    data.subarray(0, 4).toString('latin1') === 'RIFF' &&
    data.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

function toIso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

function toListView(row: PhotoNoteRow): PhotoNoteView {
  return {
    id: row.id,
    transaction_id: row.transaction_id,
    caption: row.caption,
    taken_at: toIso(row.taken_at),
    taken_on: row.taken_on,
    has_photo: row.photo_mime !== null,
    photo_mime: row.photo_mime,
    rev: row.rev,
    created_at: toIso(row.created_at),
    updated_at: toIso(row.updated_at),
  };
}

function toDetailView(row: PhotoNoteRow): PhotoNoteView {
  return {
    ...toListView(row),
    photo_base64:
      row.photo_data && row.photo_mime
        ? Buffer.from(row.photo_data).toString('base64')
        : null,
  };
}
