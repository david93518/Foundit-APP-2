import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import type { Request, Response } from 'express';
import { join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { SocketIoAdapter } from './websocket/socket-io.adapter';
import { QrLandingController } from './qr/qr-landing.controller';
import { LANDING_CSP, securityHeaders } from './common/security-headers';
import { FixedWindowLimiter } from './common/fixed-window-limiter';
import { clientIp } from './common/client-ip';
import { limiterKeyForIp } from './common/abuse-limit.interceptor';

async function bootstrap() {
  // 只解析 JSON：兩個 App 都不送 form-urlencoded，關掉它就少一個解析器（qs）暴露在外。
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bodyParser: false });
  app.useBodyParser('json', { limit: '100kb' });
  app.useWebSocketAdapter(new SocketIoAdapter(app));
  const logger = new Logger('Bootstrap');
  const production = process.env.NODE_ENV === 'production';

  app.disable('x-powered-by');
  app.use(securityHeaders(production));
  // 每個來源 IP 每分鐘最多 600 個請求。放在所有守衛之前，未登入、token 錯誤或打到不存在路徑的請求也會計入。
  const globalLimiter = new FixedWindowLimiter(600, 60_000);
  app.use((req: Request, res: Response, next: () => void) => {
    if (globalLimiter.allow(limiterKeyForIp(clientIp(req as never)))) return next();
    res.status(429).set('Retry-After', '60').json({ success: false, statusCode: 429, message: '操作太頻繁，請稍後再試' });
  });

  app.useGlobalPipes(new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
  }));

  app.useGlobalFilters(new AllExceptionsFilter());

  const origins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  app.enableCors({ origin: production ? origins : (origins.length > 0 ? origins : true) });

  // 靜態資源：圖片上傳目錄
  const uploadsDir = join(process.cwd(), 'uploads');
  if (!existsSync(uploadsDir)) mkdirSync(uploadsDir);
  app.useStaticAssets(uploadsDir, {
    prefix: '/uploads',
    dotfiles: 'deny',
    index: false,
    redirect: false,
    maxAge: '7d',
  });

  // API 前綴
  app.setGlobalPrefix('api/v1');

  // Swagger API 文件：完整路由表（含管理端）不對外公開，正式環境要明確設定 SWAGGER_ENABLED=true 才開。
  const swagger = !production || process.env.SWAGGER_ENABLED === 'true';
  if (swagger) {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('找得到 API')
      .setDescription('找得到失物共享平台後端 API 文件')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  const port = process.env.PORT ?? 3000;
  const landing = app.get(QrLandingController);
  // 這個頁面不經過 Nest 的攔截器，自己限制每個來源每 10 分鐘 60 次，避免被拿來枚舉貼紙代碼。
  const landingLimiter = new FixedWindowLimiter(60, 10 * 60_000);
  app.getHttpAdapter().get('/qr/:code', async (req, res, next) => {
    try {
      if (!landingLimiter.allow(limiterKeyForIp(clientIp(req as never)))) {
        (res as Response).status(429).type('text').set('Retry-After', '600').send('Too Many Requests');
        return;
      }
      const request = req as Request;
      const code = String(request.params?.code ?? '');
      const html = await landing.page(code, { method: request.method, userAgent: request.get('user-agent') });
      const response = res as Response;
      response.status(200).type('html')
        .set('Cache-Control', 'no-store')
        .set('Content-Security-Policy', LANDING_CSP)
        .send(html);
    } catch (error) {
      next?.(error);
    }
  });
  // Universal Links / App Links：手機相機掃到 /qr/... 時直接開進 App，只宣告這一個路徑。
  const appLinks = appLinkFiles();
  for (const [path, body] of Object.entries(appLinks)) {
    app.getHttpAdapter().get(path, (_req, res) => {
      (res as Response).status(200).type('application/json').set('Cache-Control', 'public, max-age=3600').send(body);
    });
  }
  await app.listen(port);
  logger.log(`🚀 Server running on http://localhost:${port}`);
  if (swagger) logger.log(`📚 Swagger docs: http://localhost:${port}/api/docs`);
}

/**
 * IOS_APP_IDS：逗號分隔的 `<TeamID>.<bundle id>`；ANDROID_APP_LINKS：逗號分隔的 `<package>=<簽章 SHA-256>`。
 * 沒設定 Android 就不提供 assetlinks.json（Android 版尚未上架）。
 */
function appLinkFiles(): Record<string, string> {
  const files: Record<string, string> = {};
  const iosIds = (process.env.IOS_APP_IDS ?? '3X8U3KP7SH.com.david93518.foundit')
    .split(',').map((id) => id.trim()).filter(Boolean);
  if (iosIds.length > 0) {
    files['/.well-known/apple-app-site-association'] = JSON.stringify({
      applinks: {
        apps: [],
        details: iosIds.map((id) => ({
          appID: id,
          paths: ['/qr/*'],
          appIDs: [id],
          components: [{ '/': '/qr/*', comment: '防丟牌' }],
        })),
      },
    });
  }
  const android = (process.env.ANDROID_APP_LINKS ?? '')
    .split(',').map((entry) => entry.trim().split('=')).filter((pair) => pair.length === 2 && pair[0] && pair[1]);
  if (android.length > 0) {
    files['/.well-known/assetlinks.json'] = JSON.stringify(android.map(([pkg, sha]) => ({
      relation: ['delegate_permission/common.handle_all_urls'],
      target: { namespace: 'android_app', package_name: pkg, sha256_cert_fingerprints: [sha] },
    })));
  }
  return files;
}

bootstrap();
