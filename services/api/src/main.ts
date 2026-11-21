import { ValidationPipe, Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';

import { AppModule } from './app.module.js';
import { ApiExceptionFilter } from './common/errors/api-exception.filter.js';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: false,
  });

  // Ảnh hóa đơn đi trong JSON dạng base64 (phình ~33%), trần 512KB thành
  // ~700KB. Express mặc định 100kb nên ảnh chụp thật bị 413 trước khi tới DTO.
  app.useBodyParser('json', { limit: '2mb' });
  app.useBodyParser('urlencoded', { limit: '2mb', extended: true });

  // Tắt header `X-Powered-By: Express` để không quảng cáo stack.
  app.getHttpAdapter().getInstance().disable('x-powered-by');

  // Header bảo mật: CSP, nosniff, frameguard, HSTS...
  app.use(helmet());

  // Chỉ nhận request từ nguồn được khai báo. Mặc định tắt CORS: app mobile
  // không cần CORS, chỉ web mới cần và phải khai báo rõ.
  const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (allowedOrigins.length > 0) {
    app.enableCors({
      origin: allowedOrigins,
      methods: ['GET', 'POST', 'PATCH', 'DELETE'],
      allowedHeaders: ['Authorization', 'Content-Type'],
      credentials: false,
    });
  }

  // DTO validation: sai kiểu/thiếu trường trả VALIDATION_FAILED qua filter.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      stopAtFirstError: false,
    }),
  );
  app.useGlobalFilters(new ApiExceptionFilter());

  const port = Number(process.env.PORT ?? 3000);
  // Mặc định chỉ nghe loopback: máy dev không lộ API ra Wi-Fi công cộng.
  // Đặt HOST=0.0.0.0 khi chạy trong container hoặc cần emulator truy cập.
  const host = process.env.HOST ?? '127.0.0.1';
  await app.listen(port, host);
  new Logger('Bootstrap').log(`API listening on http://${host}:${port}`);
}

await bootstrap();
