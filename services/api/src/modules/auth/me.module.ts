import { Module } from '@nestjs/common';

import { AuthModule } from '../../common/auth/auth.module.js';
import { MeController } from './me.controller.js';
import { MeService } from './me.service.js';

@Module({
  imports: [AuthModule],
  controllers: [MeController],
  providers: [MeService],
})
export class MeModule {}
