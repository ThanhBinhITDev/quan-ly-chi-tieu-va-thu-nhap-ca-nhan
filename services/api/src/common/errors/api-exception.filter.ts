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
              : status === 400 || status === 422
                ? 'VALIDATION_FAILED'
                : 'INTERNAL';
      response.status(status).json({
        error: { code, message: exception.message },
      });
      return;
    }

    this.logger.error('Unhandled error', exception instanceof Error ? exception.stack : undefined);
    response.status(500).json({
      error: { code: 'INTERNAL', message: 'Internal error' },
    });
  }
}
