import { Module } from '@nestjs/common';

import { DevLoginController } from './dev-login.controller.js';
import { DevLoginService } from './dev-login.service.js';

@Module({
  controllers: [DevLoginController],
  providers: [DevLoginService],
})
export class DevModule {}
