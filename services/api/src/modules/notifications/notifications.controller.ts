import {
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard, type AuthedRequest } from '../../common/auth/auth.guard.js';
import { ListNotificationsQuery } from './notification.dto.js';
import { NotificationsService } from './notifications.service.js';

@Controller('v1/notifications')
@UseGuards(AuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@Req() req: AuthedRequest, @Query() query: ListNotificationsQuery) {
    return this.notifications.list(req.user.id, {
      limit: query.limit,
      unreadOnly: query.unread_only === true,
    });
  }

  /** Chỉ trả con số cho badge chuông, không kéo nội dung. */
  @Get('unread-count')
  unreadCount(@Req() req: AuthedRequest) {
    return this.notifications
      .unreadCount(req.user.id)
      .then((count) => ({ unread_count: count }));
  }

  // 'read-all' khai báo trước ':id' để không bị nuốt thành tham số đường dẫn.
  @Post('read-all')
  markAllRead(@Req() req: AuthedRequest) {
    return this.notifications.markAllRead(req.user.id);
  }

  @Post(':id/read')
  markRead(@Req() req: AuthedRequest, @Param('id') id: string) {
    return this.notifications.markRead(req.user.id, id);
  }
}
