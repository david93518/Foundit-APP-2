import { IoAdapter } from '@nestjs/platform-socket.io';
import { INestApplication } from '@nestjs/common';
import { ServerOptions } from 'socket.io';

/**
 * Android 使用 io.socket:socket.io-client 2.x（Engine.IO v3），
 * 後端為 Socket.IO v4（預設僅 EIO4）；需 allowEIO3 才能握手成功。
 */
export class SocketIoAdapter extends IoAdapter {
  constructor(app: INestApplication) {
    super(app);
  }

  createIOServer(port: number, options?: ServerOptions): any {
    return super.createIOServer(port, {
      ...options,
      allowEIO3: true,
      cors: { origin: '*' },
    });
  }
}
