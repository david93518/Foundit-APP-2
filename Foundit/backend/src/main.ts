import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { SocketIoAdapter } from './websocket/socket-io.adapter';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.useWebSocketAdapter(new SocketIoAdapter(app));
  const logger = new Logger('Bootstrap');

  // 全域 Pipe：驗證請求體
  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }));

  // 全域例外過濾器
  app.useGlobalFilters(new AllExceptionsFilter());

  // CORS（Android App 不需要，保留給 Web 使用）
  app.enableCors({ origin: '*' });

  // 靜態資源：圖片上傳目錄
  const uploadsDir = join(process.cwd(), 'uploads');
  if (!existsSync(uploadsDir)) mkdirSync(uploadsDir);
  app.useStaticAssets(uploadsDir, { prefix: '/uploads' });

  // API 前綴
  app.setGlobalPrefix('api/v1');

  // Swagger API 文件
  const swaggerConfig = new DocumentBuilder()
    .setTitle('找得到 API')
    .setDescription('找得到失物共享平台後端 API 文件')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  logger.log(`🚀 Server running on http://localhost:${port}`);
  logger.log(`📚 Swagger docs: http://localhost:${port}/api/docs`);
}

bootstrap();
