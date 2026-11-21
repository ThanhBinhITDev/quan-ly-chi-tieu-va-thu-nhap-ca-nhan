import { Module } from '@nestjs/common';

import { AuthModule } from '../../common/auth/auth.module.js';
import { BudgetJarsController } from './budget-jars.controller.js';
import { BudgetJarsService } from './budget-jars.service.js';

@Module({
  imports: [AuthModule],
  controllers: [BudgetJarsController],
  providers: [BudgetJarsService],
  exports: [BudgetJarsService],
})
export class BudgetJarsModule {}
