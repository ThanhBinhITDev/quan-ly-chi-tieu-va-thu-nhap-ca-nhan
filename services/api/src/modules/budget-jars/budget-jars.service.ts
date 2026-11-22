import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import { daysLeftInPeriod, percent, vietnamMonthRange } from '../reports/report-calculator.js';
import { budgetStatus, vietnamToday } from '../budgets/budgets.service.js';
import type { CreateJarDto, UpdateJarDto } from './jar.dto.js';

export interface JarRow {
  id: string;
  name: string;
  share_pct: number;
  color: string | null;
  sort_order: number;
  category_ids: string[];
  rev: number;
}

/** Một hũ kèm số liệu tính từ giao dịch thật của tháng hiện tại. */
export interface JarProgress extends JarRow {
  /** Hạn mức tiền của hũ = ngân sách tháng × share_pct. 0 khi chưa có ngân sách. */
  amount: number;
  spent: number;
  remaining: number;
  used_pct: number;
  status: 'ok' | 'notice' | 'warning' | 'exceeded';
  days_left: number;
}

export interface JarSummary {
  as_of: string;
  /** Ngân sách tháng đang áp dụng; 0 khi người dùng chưa đặt ngân sách. */
  budget_amount: number;
  /** Tổng tỷ lệ các hũ còn sống. Lớn hơn 100 là dữ liệu sai, service chặn. */
  allocated_pct: number;
  /** Phần trăm chưa chia = 100 - allocated_pct (không âm). */
  unallocated_pct: number;
  /** Tiền chưa chia = budget_amount × unallocated_pct / 100. */
  unallocated_amount: number;
  total_spent: number;
  items: JarProgress[];
}

const COLUMNS = `id, name, share_pct, color, sort_order, rev`;

@Injectable()
export class BudgetJarsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  async list(userId: string): Promise<JarRow[]> {
    const rows = await this.db.query<JarRow & { category_ids: string[] | null }>(
      `SELECT j.id, j.name, j.share_pct, j.color, j.sort_order, j.rev,
              COALESCE(
                array_agg(jc.category_id ORDER BY jc.created_at)
                  FILTER (WHERE jc.category_id IS NOT NULL),
                '{}'
              ) AS category_ids
         FROM budget_jars j
         LEFT JOIN budget_jar_categories jc ON jc.jar_id = j.id
        WHERE j.user_id = $1 AND j.deleted_at IS NULL
        GROUP BY j.id
        ORDER BY j.sort_order, j.created_at`,
      [userId],
    );
    return rows.map(toJar);
  }

  /**
   * Tạo hũ. Kiểm hai thứ mà DB không kiểm được một mình:
   *   - tổng tỷ lệ các hũ không vượt 100% (cần đọc toàn bộ hũ);
   *   - danh mục gửi lên phải tồn tại và chưa thuộc hũ khác.
   */
  async create(userId: string, dto: CreateJarDto): Promise<JarRow> {
    const existing = await this.db.one<{ user_id: string }>(
      `SELECT user_id FROM budget_jars WHERE id = $1`,
      [dto.id],
    );
    if (existing) {
      if (existing.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Hũ ngân sách thuộc người dùng khác');
      }
      const row = await this.findById(userId, dto.id);
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy hũ');
      return row;
    }

    const categories = dto.category_ids ?? [];
    await this.assertContributionFits(userId, dto.share_pct);
    await this.assertCategoriesFree(userId, categories, null);

    return this.db.transaction(async (tx) => {
      await tx.query(
        `INSERT INTO budget_jars (id, user_id, name, share_pct, color, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          dto.id,
          userId,
          dto.name.trim(),
          dto.share_pct,
          dto.color ?? null,
          dto.sort_order ?? 0,
        ],
      );
      await this.replaceCategories(tx, dto.id, categories);
      const row = await this.findById(userId, dto.id, tx);
      if (!row) throw new ApiError('INTERNAL', 'Không tạo được hũ');
      return row;
    });
  }

  async update(userId: string, id: string, dto: UpdateJarDto): Promise<JarRow> {
    const current = await this.findById(userId, id);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy hũ');
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }
    if (dto.share_pct !== undefined) {
      await this.assertContributionFits(userId, dto.share_pct, id);
    }
    if (dto.category_ids !== undefined) {
      await this.assertCategoriesFree(userId, dto.category_ids, id);
    }

    return this.db.transaction(async (tx) => {
      const row = await tx.one<JarRow>(
        `UPDATE budget_jars
            SET name = COALESCE($3, name),
                share_pct = COALESCE($4, share_pct),
                color = COALESCE($5, color),
                sort_order = COALESCE($6, sort_order),
                rev = rev + 1
          WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
          RETURNING ${COLUMNS}`,
        [
          id,
          userId,
          dto.name?.trim() ?? null,
          dto.share_pct ?? null,
          dto.color ?? null,
          dto.sort_order ?? null,
        ],
      );
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy hũ');
      if (dto.category_ids !== undefined) {
        await this.replaceCategories(tx, id, dto.category_ids);
      }
      // Trả kèm danh mục mới nhất, không chỉ cột của bảng hũ.
      const withCats = await this.findById(userId, id, tx);
      return withCats ?? toJar({ ...row, category_ids: [] } as never);
    });
  }

  /** Xoá mềm: hũ biến mất khỏi danh sách nhưng dữ liệu còn để đối soát. */
  async remove(userId: string, id: string, rev: number): Promise<void> {
    const current = await this.findById(userId, id);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy hũ');
    if (rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }
    await this.db.query(
      `UPDATE budget_jars
          SET deleted_at = now(), rev = rev + 1
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [id, userId],
    );
  }

  /**
   * Tiến độ từng hũ trong tháng hiện tại.
   *
   * Hạn mức của hũ = ngân sách tháng × tỷ lệ hũ. Ngân sách tháng lấy theo
   * ngân sách "Tổng" đang áp dụng; không có ngân sách Tổng thì cộng các ngân
   * sách danh mục — cùng quy ước với tab Ngân sách, tránh hai màn hình ra hai
   * con số khác nhau.
   */
  async progress(userId: string): Promise<JarSummary> {
    const jars = await this.list(userId);
    const asOf = vietnamToday();
    const [year, month] = asOf.split('-').map(Number);
    const range = vietnamMonthRange(year, month);

    const budgetAmount = await this.monthBudget(userId, asOf);

    const spentRows = await this.db.query<{ category_id: string | null; total: string }>(
      `SELECT category_id, SUM(amount)::text AS total
         FROM transactions
        WHERE user_id = $1
          AND deleted_at IS NULL
          AND type = 'expense'
          AND occurred_on BETWEEN $2::date AND $3::date
        GROUP BY category_id`,
      [userId, range.start, range.end],
    );
    const spentByCategory = new Map<string | null, number>();
    let totalSpent = 0;
    for (const row of spentRows) {
      const value = Number(row.total);
      spentByCategory.set(row.category_id, value);
      totalSpent += value;
    }

    const daysLeft = daysLeftInPeriod(
      new Date(`${asOf}T00:00:00Z`),
      new Date(`${range.start}T00:00:00Z`),
      new Date(`${range.end}T00:00:00Z`),
    );

    const allocatedPct = jars.reduce((sum, jar) => sum + jar.share_pct, 0);
    const items: JarProgress[] = jars.map((jar) => {
      const amount = Math.round((budgetAmount * jar.share_pct) / 100);
      // Hũ không gắn danh mục nào thì chưa quy được chi tiêu: để 0 thay vì
      // cộng toàn bộ chi tiêu tháng, nếu không hũ rỗng sẽ hiện "đã cạn".
      const spent = jar.category_ids.reduce(
        (sum, categoryId) => sum + (spentByCategory.get(categoryId) ?? 0),
        0,
      );
      const remaining = amount - spent;
      const usedPct = percent(spent, amount);
      return {
        ...jar,
        amount,
        spent,
        remaining,
        used_pct: usedPct,
        status: budgetStatus(usedPct),
        days_left: daysLeft,
      };
    });

    const unallocatedPct = Math.max(0, 100 - allocatedPct);
    return {
      as_of: asOf,
      budget_amount: budgetAmount,
      allocated_pct: allocatedPct,
      unallocated_pct: unallocatedPct,
      unallocated_amount: Math.round((budgetAmount * unallocatedPct) / 100),
      total_spent: totalSpent,
      items,
    };
  }

  /** Ngân sách tháng đang áp dụng, cùng quy ước với `BudgetsService.progress`. */
  private async monthBudget(userId: string, asOf: string): Promise<number> {
    const rows = await this.db.query<{ amount: string; is_total: boolean }>(
      `SELECT amount::text AS amount, (category_id IS NULL) AS is_total
         FROM budgets
        WHERE user_id = $1
          AND deleted_at IS NULL
          AND period = 'month'
          AND start_date <= $2::date
          AND (end_date IS NULL OR end_date >= $2::date)`,
      [userId, asOf],
    );
    const total = rows.find((row) => row.is_total);
    if (total) return Number(total.amount);
    return rows.reduce((sum, row) => sum + Number(row.amount), 0);
  }

  /** Tổng tỷ lệ sau khi thêm/sửa không được vượt 100%. */
  private async assertContributionFits(
    userId: string,
    sharePct: number,
    exceptId?: string,
  ): Promise<void> {
    const row = await this.db.one<{ total: string }>(
      `SELECT COALESCE(SUM(share_pct), 0)::text AS total
         FROM budget_jars
        WHERE user_id = $1
          AND deleted_at IS NULL
          AND ($2::uuid IS NULL OR id <> $2::uuid)`,
      [userId, exceptId ?? null],
    );
    const used = Number(row?.total ?? 0);
    if (used + sharePct > 100) {
      throw new ApiError(
        'RULE_VIOLATION',
        `Tổng tỷ lệ các hũ không được vượt 100% (đang dùng ${used}%)`,
        { details: { allocated_pct: used, requested_pct: sharePct } },
      );
    }
  }

  /** Danh mục phải tồn tại và chưa thuộc hũ khác. */
  private async assertCategoriesFree(
    userId: string,
    categoryIds: string[],
    exceptJarId: string | null,
  ): Promise<void> {
    if (categoryIds.length === 0) return;
    const rows = await this.db.query<{ id: string; jar_id: string | null; jar_name: string | null }>(
      `SELECT c.id, jc.jar_id, j.name AS jar_name
         FROM categories c
         LEFT JOIN budget_jar_categories jc ON jc.category_id = c.id
         LEFT JOIN budget_jars j
                ON j.id = jc.jar_id AND j.deleted_at IS NULL
        WHERE c.id = ANY($1::uuid[])
          AND (c.user_id IS NULL OR c.user_id = $2)
          AND c.deleted_at IS NULL`,
      [categoryIds, userId],
    );
    const found = new Set(rows.map((row) => row.id));
    const missing = categoryIds.filter((id) => !found.has(id));
    if (missing.length > 0) {
      throw new ApiError('NOT_FOUND', 'Danh mục không tồn tại', {
        details: { category_ids: missing },
      });
    }
    const taken = rows.filter(
      (row) => row.jar_id !== null && row.jar_id !== exceptJarId,
    );
    if (taken.length > 0) {
      throw new ApiError(
        'RULE_VIOLATION',
        `Danh mục đã thuộc hũ khác: ${taken.map((row) => row.jar_name).join(', ')}`,
        { details: { category_ids: taken.map((row) => row.id) } },
      );
    }
  }

  private async replaceCategories(
    tx: Database,
    jarId: string,
    categoryIds: string[],
  ): Promise<void> {
    await tx.query(`DELETE FROM budget_jar_categories WHERE jar_id = $1`, [jarId]);
    for (const categoryId of categoryIds) {
      await tx.query(
        `INSERT INTO budget_jar_categories (jar_id, category_id)
         VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [jarId, categoryId],
      );
    }
  }

  private async findById(
    userId: string,
    id: string,
    db: Database = this.db,
  ): Promise<JarRow | null> {
    const row = await db.one<JarRow & { category_ids: string[] | null }>(
      `SELECT j.id, j.name, j.share_pct, j.color, j.sort_order, j.rev,
              COALESCE(
                array_agg(jc.category_id ORDER BY jc.created_at)
                  FILTER (WHERE jc.category_id IS NOT NULL),
                '{}'
              ) AS category_ids
         FROM budget_jars j
         LEFT JOIN budget_jar_categories jc ON jc.jar_id = j.id
        WHERE j.id = $1 AND j.user_id = $2 AND j.deleted_at IS NULL
        GROUP BY j.id`,
      [id, userId],
    );
    return row ? toJar(row) : null;
  }
}

function toJar(row: JarRow & { category_ids: string[] | null }): JarRow {
  return {
    id: row.id,
    name: row.name,
    share_pct: Number(row.share_pct),
    color: row.color,
    sort_order: Number(row.sort_order),
    category_ids: row.category_ids ?? [],
    rev: Number(row.rev),
  };
}
