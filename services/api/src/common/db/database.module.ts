import { Global, Module } from '@nestjs/common';

import { DATABASE } from './database.js';
import { PostgresDatabase } from './postgres.database.js';

@Global()
@Module({
  providers: [{ provide: DATABASE, useClass: PostgresDatabase }],
  exports: [DATABASE],
})
export class DatabaseModule {}
