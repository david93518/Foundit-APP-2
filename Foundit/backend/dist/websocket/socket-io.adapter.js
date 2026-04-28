"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SocketIoAdapter = void 0;
const platform_socket_io_1 = require("@nestjs/platform-socket.io");
class SocketIoAdapter extends platform_socket_io_1.IoAdapter {
    constructor(app) {
        super(app);
    }
    createIOServer(port, options) {
        return super.createIOServer(port, {
            ...options,
            allowEIO3: true,
            cors: { origin: '*' },
        });
    }
}
exports.SocketIoAdapter = SocketIoAdapter;
//# sourceMappingURL=socket-io.adapter.js.map