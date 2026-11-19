import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type { CreateCategoryDto, UpdateCategoryDto } from './category.dto.js';

export interface CategoryRow {
  id: string;
  user_id: string | null;
  name: string;
  type: string;
  icon: string | null;
  color: string | null;
  parent_id: string | null;
  is_system: boolean;
  sort_order: number;
  rev: number;
}

const COLUMNS = `id, user_id, name, type, icon, color, parent_id, is_system,
       sort_order, rev`;

@Injectable()
export class CategoriesService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /**
   * Danh mục hệ thống (user_id IS NULL) dùng chung cho mọi người,
   * cộng danh mục riêng của người dùng.
   */
  async list(userId: string, type?: string): Promise<CategoryRow[]> {
    const params: unknown[] = [userId];
    let filter = '';
    if (type) {
      params.push(type);
      filter = ` AND type = $${params.length}`;
    }
    return this.db.query<CategoryRow>(
      `SELECT ${COLUMNS}
         FROM categories
        WHERE (user_id IS NULL OR user_id = $1)
          AND deleted_at IS NULL${filter}
        ORDER BY is_system DESC, sort_order, name`,
      params,
    );
  }

  async create(userId: string, dto: CreateCategoryDto): Promise<CategoryRow> {
    const existing = await this.db.one<{ id: string; user_id: string | null }>(
      `SELECT id, user_id FROM categories WHERE id = $1`,
      [dto.id],
    );
    if (existing) {
      // Không cho "chiếm" danh mục hệ thống bằng cách gửi lại id của nó.
      if (existing.user_id !== userId) {
        throw new ApiError(
          'FORBIDDEN',
          'Không thể ghi đè danh mục hệ thống hoặc của người khác',
        );
      }
      const row = await this.findById(userId, dto.id);
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy danh mục');
      return row;
    }

    if (dto.parent_id) {
      const parent = await this.db.one<{ id: string }>(
        `SELECT id FROM categories
          WHERE id = $1 AND (user_id IS NULL OR user_id = $2) AND deleted_at IS NULL`,
        [dto.parent_id, userId],
      );
      if (!parent) {
        throw new ApiError('NOT_FOUND', 'Danh mục cha không tồn tại', {
          field: 'parent_id',
        });
      }
    }

    const row = await this.db.one<CategoryRow>(
      `INSERT INTO categories
         (id, user_id, name, type, icon, color, parent_id, is_system)
       VALUES ($1, $2, $3, $4, $5, $6, $7, false)
       RETURNING ${COLUMNS}`,
      [
        dto.id,
        userId,
        dto.name,
        dto.type,
        dto.icon ?? null,
        dto.color ?? null,
        dto.parent_id ?? null,
      ],
    );
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được danh mục');
    return row;
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateCategoryDto,
  ): Promise<CategoryRow> {
    const current = await this.findById(userId, id);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy danh mục');
    if (current.is_system) {
      throw new ApiError('FORBIDDEN', 'Danh mục hệ thống không sửa được');
    }
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }

    const row = await this.db.one<CategoryRow>(
      `UPDATE categories
          SET name = COALESCE($3, name),
              icon = COALESCE($4, icon),
              color = COALESCE($5, color),
              sort_order = COALESCE($6, sort_order),
              rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
        RETURNING ${COLUMNS}`,
      [
        id,
        userId,
        dto.name ?? null,
        dto.icon ?? null,
        dto.color ?? null,
        dto.sort_order ?? null,
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy danh mục');
    return row;
  }

  private async findById(
    userId: string,
    id: string,
  ): Promise<CategoryRow | null> {
    return this.db.one<CategoryRow>(
      `SELECT ${COLUMNS}
         FROM categories
        WHERE id = $1 AND (user_id IS NULL OR user_id = $2) AND deleted_at IS NULL`,
      [id, userId],
    );
  }
}
