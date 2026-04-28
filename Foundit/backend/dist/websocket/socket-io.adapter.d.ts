import { IoAdapter } from '@nestjs/platform-socket.io';
import { INestApplication } from '@nestjs/common';
import { ServerOptions } from 'socket.io';
export declare class SocketIoAdapter extends IoAdapter {
    constructor(app: INestApplication);
    createIOServer(port: number, options?: ServerOptions): any;
}
