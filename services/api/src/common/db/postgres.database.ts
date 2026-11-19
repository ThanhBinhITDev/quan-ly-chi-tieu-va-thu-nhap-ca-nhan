import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { Pool, types, type PoolClient, type PoolConfig } from 'pg';

import type { Database } from './database.js';

/**
 * Cột DATE (OID 1082) mặc định bị `pg` đổi thành `Date` object theo múi giờ
 * của tiến trình Node, rồi JSON.stringify ra ISO timestamp lệch ngày
 * (ví dụ '2026-11-20' -> '2026-11-19T17:00:00.000Z').
 *
 * Cột `occurred_on`, `deadline`, `period_start`... là ngày lịch, không phải
 * thời điểm. Trả nguyên chuỗi 'YYYY-MM-DD' để client nhận đúng ngày.
 */
types.setTypeParser(types.builtins.DATE, (value: string) => value);

/** Bọc một PoolClient để dùng trong transaction. */
class TransactionDatabase implements Database {
  constructor(private readonly client: PoolClient) {}

  async query<T>(sql: string, params: unknown[] = []): Promise<T[]> {
    const result = await this.client.query(sql, params);
    return result.rows as T[];
  }

  async one<T>(sql: string, params: unknown[] = []): Promise<T | null> {
    const rows = await this.query<T>(sql, params);
    return rows[0] ?? null;
  }

  async transaction<T>(fn: (tx: Database) => Promise<T>): Promise<T> {
    // Hỗ trợ gọi transaction lồng nhau: dùng lại client hiện tại.
    return fn(this);
  }
}

/**
 * Kết nối Postgres (Supabase). Chỉ dùng từ server, không bao giờ lộ ra client.
 *
 * Biến môi trường:
 * - DATABASE_URL: chuỗi kết nối Postgres (bắt buộc khi chạy thật)
 * - DATABASE_SSL: 'false' để tắt TLS (mặc định bật)
 */
@Injectable()
export class PostgresDatabase implements Database, OnModuleDestroy {
  private readonly logger = new Logger(PostgresDatabase.name);
  private readonly pool: Pool | null;

  constructor() {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
      this.logger.warn(
        'DATABASE_URL chưa được đặt. API sẽ khởi động nhưng mọi truy vấn sẽ lỗi.',
      );
      this.pool = null;
      return;
    }
    const config: PoolConfig = {
      connectionString,
      max: Number(process.env.DATABASE_POOL_MAX ?? 10),
      ssl:
        process.env.DATABASE_SSL === 'false'
          ? false
          : { rejectUnauthorized: process.env.DATABASE_SSL_STRICT === 'true' },
    };
    this.pool = new Pool(config);
  }

  private requirePool(): Pool {
    if (!this.pool) {
      throw new Error('DATABASE_URL is not configured');
    }
    return this.pool;
  }

  async query<T>(sql: string, params: unknown[] = []): Promise<T[]> {
    const result = await this.requirePool().query(sql, params);
    return result.rows as T[];
  }

  async one<T>(sql: string, params: unknown[] = []): Promise<T | null> {
    const rows = await this.query<T>(sql, params);
    return rows[0] ?? null;
  }

  async transaction<T>(fn: (tx: Database) => Promise<T>): Promise<T> {
    const client = await this.requirePool().connect();
    try {
      await client.query('BEGIN');
      const result = await fn(new TransactionDatabase(client));
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool?.end();
  }
}
