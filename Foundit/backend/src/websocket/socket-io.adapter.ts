import { IoAdapter } from '@nestjs/platform-socket.io';
import { INestApplication } from '@nestjs/common';
import { IncomingMessage } from 'http';
import { ServerOptions } from 'socket.io';
import { clientIp } from '../common/client-ip';
import { limiterKeyForIp } from '../common/abuse-limit.interceptor';
import { FixedWindowLimiter } from '../common/fixed-window-limiter';

export class SocketIoAdapter extends IoAdapter {
  /** 每個來源 IP 每分鐘最多建立 30 條 Socket.IO 連線（握手），擋連線洪水。 */
  private readonly handshakes = new FixedWindowLimiter(30, 60_000);

  constructor(app: INestApplication) {
    super(app);
  }

  createIOServer(port: number, options?: ServerOptions): any {
    return super.createIOServer(port, {
      ...options,
      // Flutter 的 socket_io_client 走 Engine.IO v4；舊 Android 原生版本已不再支援。
      allowEIO3: process.env.SOCKET_ALLOW_EIO3 === 'true',
      // 文字訊息上限 2000 字，64 KB 足夠；預設 1 MB 讓單一封包就能吃掉大量記憶體。
      maxHttpBufferSize: 64 * 1024,
      allowRequest: (req: IncomingMessage, callback: (err: string | null | undefined, ok: boolean) => void) => {
        callback(null, this.handshakes.allow(limiterKeyForIp(clientIp(req as never))));
      },
      cors: options?.cors ?? {
        origin: process.env.NODE_ENV === 'production'
          ? (process.env.CORS_ORIGINS ?? '').split(',').map(value => value.trim()).filter(Boolean)
          : true,
      },
    });
  }
}
