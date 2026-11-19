import { Controller, Get, Inject } from '@nestjs/common';

import { DATABASE, type Database } from '../db/database.js';

@Controller()
export class HealthController {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /** Kiểm tra API sống và có nói chuyện được với database không. */
  @Get('health')
  async health() {
    let database = 'down';
    try {
      await this.db.one<{ ok: number }>('SELECT 1 AS ok');
      database = 'up';
    } catch {
      database = 'down';
    }
    return { status: 'ok', database, time: new Date().toISOString() };
  }
}
