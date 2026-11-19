import type { Database } from '../src/common/db/database.js';

export interface FakeRow {
  [key: string]: unknown;
}

/**
 * Database giả cho unit test: trả lời theo thứ tự handler đã đăng ký.
 * Mỗi handler nhận (sql, params) và trả mảng dòng.
 */
export class FakeDatabase implements Database {
  private handlers: Array<(sql: string, params: unknown[]) => FakeRow[]> = [];

  /** SQL của lần gọi gần nhất; dùng để khẳng định câu truy vấn có lọc đúng. */
  lastSql = '';

  /** Toàn bộ SQL đã chạy, theo thứ tự. */
  readonly executed: string[] = [];

  on(matcher: RegExp | string, rows: FakeRow[] | ((params: unknown[]) => FakeRow[])) {
    const test =
      typeof matcher === 'string'
        ? (sql: string) => sql.includes(matcher)
        : (sql: string) => matcher.test(sql);
    this.handlers.push((sql, params) =>
      test(sql) ? (typeof rows === 'function' ? rows(params) : rows) : [],
    );
    return this;
  }

  async query<T>(sql: string, params: unknown[] = []): Promise<T[]> {
    this.lastSql = sql;
    this.executed.push(sql);
    for (const handler of this.handlers) {
      const rows = handler(sql, params);
      if (rows.length > 0) return rows as T[];
    }
    return [];
  }

  async one<T>(sql: string, params: unknown[] = []): Promise<T | null> {
    const rows = await this.query<T>(sql, params);
    return rows[0] ?? null;
  }

  async transaction<T>(fn: (tx: Database) => Promise<T>): Promise<T> {
    // Bản giả không rollback: test tự kiểm tra hệ quả.
    return fn(this);
  }
}
