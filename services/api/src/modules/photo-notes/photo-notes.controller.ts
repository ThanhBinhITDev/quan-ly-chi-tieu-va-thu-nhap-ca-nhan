import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import {
  CreatePhotoNoteDto,
  ListPhotoNotesQuery,
  UpdatePhotoNoteDto,
} from './photo-note.dto.js';
import { PhotoNotesService } from './photo-notes.service.js';

@Controller('v1/photo-notes')
@UseGuards(AuthGuard)
export class PhotoNotesController {
  constructor(private readonly photos: PhotoNotesService) {}

  @Get()
  list(@Req() req: AuthedRequest, @Query() query: ListPhotoNotesQuery) {
    return this.photos.list(req.user.id, query);
  }

  @Get(':id')
  findOne(@Req() req: AuthedRequest, @Param('id') id: string) {
    return this.photos.findOne(req.user.id, id);
  }

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreatePhotoNoteDto) {
    return this.photos.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
    @Body() dto: UpdatePhotoNoteDto,
  ) {
    return this.photos.update(req.user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@Req() req: AuthedRequest, @Param('id') id: string) {
    await this.photos.remove(req.user.id, id);
  }
}
