import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AuthModule } from './common/auth/auth.module.js';
import { DatabaseModule } from './common/db/database.module.js';
import { HealthController } from './common/http/health.controller.js';
import { MeModule } from './modules/auth/me.module.js';
import { BudgetsModule } from './modules/budgets/budgets.module.js';
import { CategoriesModule } from './modules/categories/categories.module.js';
import { DevicesModule } from './modules/devices/devices.module.js';
import { GoalsModule } from './modules/goals/goals.module.js';
import { GroupsModule } from './modules/groups/groups.module.js';
import { ReportsModule } from './modules/reports/reports.module.js';
import { SyncModule } from './modules/sync/sync.module.js';
import { TransactionsModule } from './modules/transactions/transactions.module.js';
import { WalletsModule } from './modules/wallets/wallets.module.js';

@Module({
  imports: [
    // Đọc .env (không ghi đè biến môi trường đã có, để production tự quyết).
    ConfigModule.forRoot({ isGlobal: true, cache: true }),
    DatabaseModule,
    AuthModule,
    MeModule,
    WalletsModule,
    CategoriesModule,
    TransactionsModule,
    BudgetsModule,
    ReportsModule,
    DevicesModule,
    GoalsModule,
    GroupsModule,
    SyncModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
