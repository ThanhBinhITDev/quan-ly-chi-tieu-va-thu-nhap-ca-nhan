import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';

import { ApiError } from './api-error.js';

/**
 * Chuyển mọi lỗi về đúng định dạng `{ error: { code, message } }`.
 * Lỗi không xác định trả INTERNAL và không lộ chi tiết kỹ thuật ra ngoài.
 */
@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof ApiError) {
      response.status(exception.status).json(exception.toBody());
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const code =
        status === 401
          ? 'UNAUTHENTICATED'
          : status === 403
            ? 'FORBIDDEN'
            : status === 404
              ? 'NOT_FOUND'
              : status === 429
                ? 'RATE_LIMITED'
                : status === 400 || status === 422
                  ? 'VALIDATION_FAILED'
                  : 'INTERNAL';
      // Thông báo mặc định của Nest (`ThrottlerException: Too Many
      // Requests`) là thông điệp kỹ thuật, không dành cho người dùng cuối.
      const message =
        status === 429
          ? 'Bạn thao tác quá nhanh, vui lòng thử lại sau'
          : status === 400 && exception.message === 'Bad Request Exception'
            ? 'Dữ liệu gửi lên không hợp lệ'
            : exception.message;
      response.status(status).json({ error: { code, message } });
      return;
    }

    this.logger.error('Unhandled error', exception instanceof Error ? exception.stack : undefined);
    response.status(500).json({
      error: { code: 'INTERNAL', message: 'Internal error' },
    });
  }
}
