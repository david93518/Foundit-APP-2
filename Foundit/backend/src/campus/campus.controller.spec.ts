import { ExecutionContext, INestApplication } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AbuseLimitInterceptor } from '../common/abuse-limit.interceptor';
import { OptionalJwtAuthGuard } from '../common/guards/optional-jwt-auth.guard';
import { MediaStorageService } from '../upload/media-storage.service';
import { CampusController } from './campus.controller';
import { CampusService } from './campus.service';

describe('CampusController rate limits', () => {
  let app: INestApplication;
  const call = jest.fn((name: string) => Promise.resolve(name));

  beforeEach(async () => {
    call.mockClear();
    const module = await Test.createTestingModule({
      controllers: [CampusController],
      providers: [
        { provide: CampusService, useValue: { call } },
        { provide: MediaStorageService, useValue: {} },
        { provide: ConfigService, useValue: {} },
        { provide: APP_INTERCEPTOR, useClass: AbuseLimitInterceptor },
      ],
    })
      .overrideGuard(OptionalJwtAuthGuard)
      .useValue({
        canActivate(context: ExecutionContext) {
          const req = context.switchToHttp().getRequest<{
            headers: Record<string, string>;
            user?: { id: string };
          }>();
          if (req.headers['x-test-user'])
            req.user = { id: req.headers['x-test-user'] };
          return true;
        },
      })
      .compile();
    app = module.createNestApplication();
    await app.init();
  });

  afterEach(() => app.close());

  // 所有人都從同一個校園 Wi-Fi 出去：同一個對外 IP。
  const post = (path: string, user?: string) => {
    const req = request(app.getHttpServer())
      .post(path)
      .set('cf-connecting-ip', '203.0.113.7')
      .send({});
    return user ? req.set('x-test-user', user) : req;
  };
  const times = async (n: number, path: string, user?: string) => {
    for (let i = 0; i < n; i += 1) await post(path, user).expect(201);
  };

  it('still limits anonymous calls per IP', async () => {
    await times(120, '/campus/rpc/sticker_lookup');
    await post('/campus/rpc/sticker_lookup').expect(429);
  });

  it('gives each signed-in account its own quota on a shared IP', async () => {
    await times(120, '/campus/rpc/my_stickers', 'a');
    await times(120, '/campus/rpc/my_stickers', 'b');
    await post('/campus/rpc/sticker_lookup').expect(201);
    await post('/campus/rpc/my_stickers', 'a').expect(429);
  });

  it('counts finder chat polling separately, with a higher ceiling', async () => {
    await times(300, '/campus/rpc/sticker_thread_finder');
    expect(call).toHaveBeenLastCalledWith(
      'sticker_thread_finder',
      {},
      undefined,
    );
    await post('/campus/rpc/sticker_lookup').expect(201);
    await times(300, '/campus/rpc/STICKER_THREAD_FINDER');
    expect(call).toHaveBeenLastCalledWith(
      'sticker_thread_finder',
      {},
      undefined,
    );
    await post('/campus/rpc/sticker_thread_finder').expect(429);
  });
});
