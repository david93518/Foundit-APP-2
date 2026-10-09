import { JwtService } from '@nestjs/jwt';
import { ChatsGateway } from './chats.gateway';
import { Socket } from 'socket.io';

const id = '11111111-1111-4111-8111-111111111111';
const secret = 'socket-regression-secret-with-more-than-32-characters';
describe('socket session security', () => {
  const jwt = new JwtService({ secret });
  let user: { id: string; status: string; tokenVersion: number };
  let gateway: ChatsGateway;
  let client: Socket;
  beforeEach(() => {
    jest.useFakeTimers();
    user = { id, status: 'active', tokenVersion: 0 };
    gateway = new ChatsGateway({ assertParticipant: jest.fn() } as never, jwt,
      { findOne: jest.fn(async () => ({ ...user })) } as never);
    client = { id: 'socket1', data: {}, connected: true,
      handshake: { auth: { token: jwt.sign({ sub: id, tv: 0 }, { expiresIn: '1m' }) }, headers: {} },
      disconnect: jest.fn(), join: jest.fn(), rooms: new Set<string>(),
    } as unknown as Socket;
  });
  afterEach(() => { gateway.handleDisconnect(client); jest.useRealTimers(); });

  it('rejects an existing socket after revocation on another replica', async () => {
    await gateway.handleConnection(client);
    user.tokenVersion++;
    await expect(gateway.handleJoin(client, { chatId: id })).rejects.toThrow('登入已失效');
    expect(client.disconnect).toHaveBeenCalledWith(true);
  });
  it('disconnects idle sockets at token expiry', async () => {
    await gateway.handleConnection(client);
    await jest.advanceTimersByTimeAsync(60_000);
    expect(client.disconnect).toHaveBeenCalledWith(true);
  });
  it('reconnecting does not reset the account event quota', async () => {
    await gateway.handleConnection(client);
    for (let n = 0; n < 120; n++) await gateway.handleJoin(client, { chatId: id });
    const next = { ...client, id: 'socket2', data: {} } as unknown as Socket;
    await gateway.handleConnection(next);
    try { await expect(gateway.handleJoin(next, { chatId: id })).rejects.toThrow('操作太頻繁'); }
    finally { gateway.handleDisconnect(next); }
  });
  it('checks recipients before delivering private messages', async () => {
    await gateway.handleConnection(client);
    const emit = jest.fn();
    gateway.server = { in: () => ({ fetchSockets: async () => [{ data: client.data, emit, disconnect: client.disconnect }] }) } as never;
    user.status = 'suspended';
    await gateway.pushToChat(id, 'message', { content: 'private' });
    expect(emit).not.toHaveBeenCalled();
    expect(client.disconnect).toHaveBeenCalled();
  });
});
