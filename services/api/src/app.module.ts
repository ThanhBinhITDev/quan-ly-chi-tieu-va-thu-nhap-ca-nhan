import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import { AuthModule } from './common/auth/auth.module.js';
import { DatabaseModule } from './common/db/database.module.js';
import { HealthController } from './common/http/health.controller.js';
import { MeModule } from './modules/auth/me.module.js';
import { BudgetJarsModule } from './modules/budget-jars/budget-jars.module.js';
import { BudgetsModule } from './modules/budgets/budgets.module.js';
import { CategoriesModule } from './modules/categories/categories.module.js';
import { DevModule } from './modules/dev/dev.module.js';
import { DevicesModule } from './modules/devices/devices.module.js';
import { GoalsModule } from './modules/goals/goals.module.js';
import { GroupsModule } from './modules/groups/groups.module.js';
import { NotificationsModule } from './modules/notifications/notifications.module.js';
import { PhotoNotesModule } from './modules/photo-notes/photo-notes.module.js';
import { ReportsModule } from './modules/reports/reports.module.js';
import { SyncModule } from './modules/sync/sync.module.js';
import { TransactionsModule } from './modules/transactions/transactions.module.js';
import { WalletsModule } from './modules/wallets/wallets.module.js';

@Module({
  imports: [
    // Đọc .env (không ghi đè biến môi trường đã có, để production tự quyết).
    ConfigModule.forRoot({ isGlobal: true, cache: true }),
    // Giới hạn số request mỗi IP: chặn dò mật khẩu, spam tạo tài nguyên và
    // lạm dụng API. 60 request/phút là đủ cho app dùng bình thường (đồng bộ
    // theo lô đã gộp nhiều bản ghi trong một request).
    ThrottlerModule.forRoot([
      {
        ttl: Number(process.env.THROTTLE_TTL_MS ?? 60_000),
        limit: Number(process.env.THROTTLE_LIMIT ?? 60),
      },
    ]),
    DatabaseModule,
    AuthModule,
    MeModule,
    WalletsModule,
    CategoriesModule,
    TransactionsModule,
    BudgetsModule,
    BudgetJarsModule,
    ReportsModule,
    DevicesModule,
    GoalsModule,
    GroupsModule,
    NotificationsModule,
    PhotoNotesModule,
    SyncModule,
    // Đăng nhập giả lập cho dev. Tự tắt khi NODE_ENV=production hoặc thiếu
    // DEV_LOGIN_PASSWORD — xem DevLoginService.assertEnabled.
    DevModule,
  ],
  controllers: [HealthController],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
