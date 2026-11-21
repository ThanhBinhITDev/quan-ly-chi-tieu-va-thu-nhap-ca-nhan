import { Module } from '@nestjs/common';

import { AuthModule } from '../../common/auth/auth.module.js';
import { PhotoNotesController } from './photo-notes.controller.js';
import { PhotoNotesService } from './photo-notes.service.js';

@Module({
  imports: [AuthModule],
  controllers: [PhotoNotesController],
  providers: [PhotoNotesService],
})
export class PhotoNotesModule {}
