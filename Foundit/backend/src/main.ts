import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { SocketIoAdapter } from './websocket/socket-io.adapter';
import { QrLandingController } from './qr/qr-landing.controller';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.useWebSocketAdapter(new SocketIoAdapter(app));
  const logger = new Logger('Bootstrap');

  app.useGlobalPipes(new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
  }));

  app.useGlobalFilters(new AllExceptionsFilter());

  const production = process.env.NODE_ENV === 'production';
  const origins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  app.enableCors({ origin: production ? origins : (origins.length > 0 ? origins : true) });

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
  const landing = app.get(QrLandingController);
  app.getHttpAdapter().get('/qr/:code', async (req, res, next) => {
    try {
      const code = String((req as { params?: { code?: string } }).params?.code ?? '');
      const html = await landing.page(code);
      const response = res as { status: (status: number) => { type: (value: string) => { set: (key: string, header: string) => { send: (body: string) => void } } } };
      response.status(200).type('html').set('Cache-Control', 'no-store').send(html);
    } catch (error) {
      next?.(error);
    }
  });
  await app.listen(port);
  logger.log(`🚀 Server running on http://localhost:${port}`);
  logger.log(`📚 Swagger docs: http://localhost:${port}/api/docs`);
}

bootstrap();
