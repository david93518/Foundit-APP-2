import { JwtService } from '@nestjs/jwt';
import { ForbiddenException } from '@nestjs/common';
import { Socket } from 'socket.io';
import { ChatsGateway } from './chats.gateway';

const me = '11111111-1111-4111-8111-111111111111';
const peer = '22222222-2222-4222-8222-222222222222';
const chatId = '33333333-3333-4333-8333-333333333333';
const secret = 'presence-regression-secret-with-more-than-32-characters';

describe('chat presence and inbox events', () => {
  const jwt = new JwtService({ secret });
  let gateway: ChatsGateway;
  let client: Socket;
  let assertParticipant: jest.Mock;
  let rooms: Record<string, Array<{ data: { authenticated?: boolean } }>>;
  let emitted: Array<{ room: string; event: string; payload: unknown }>;

  beforeEach(() => {
    assertParticipant = jest.fn().mockResolvedValue(undefined);
    gateway = new ChatsGateway(
      { assertParticipant, participantIds: jest.fn().mockResolvedValue([me, peer]) } as never,
      jwt,
      { findOne: jest.fn(async () => ({ id: me, status: 'active', tokenVersion: 0 })) } as never,
    );
    rooms = {};
    emitted = [];
    gateway.server = {
      in: (room: string) => ({ fetchSockets: async () => rooms[room] ?? [] }),
      to: (room: string) => ({ emit: (event: string, payload: unknown) => emitted.push({ room, event, payload }) }),
    } as never;
    client = { id: 'socket1', data: {}, connected: true,
      handshake: { auth: { token: jwt.sign({ sub: me, tv: 0 }, { expiresIn: '1m' }) }, headers: {} },
      disconnect: jest.fn(), join: jest.fn(), rooms: new Set<string>(),
    } as unknown as Socket;
  });
  afterEach(() => gateway.handleDisconnect(client));

  it('joins a per-account room on connect', async () => {
    await gateway.handleConnection(client);
    expect(client.join).toHaveBeenCalledWith(`user:${me}`);
  });

  it('reports the other participant as online only while they have an authenticated socket', async () => {
    await gateway.handleConnection(client);
    expect(await gateway.handlePresence(client, { chatId })).toEqual({ chatId, online: false });
    rooms[`user:${peer}`] = [{ data: { authenticated: false } }];
    expect((await gateway.handlePresence(client, { chatId })).online).toBe(false);
    rooms[`user:${peer}`] = [{ data: { authenticated: true } }];
    expect((await gateway.handlePresence(client, { chatId })).online).toBe(true);
  });

  it('does not reveal presence to non-participants', async () => {
    await gateway.handleConnection(client);
    assertParticipant.mockRejectedValue(new ForbiddenException());
    await expect(gateway.handlePresence(client, { chatId })).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('sends only the chat id to every participant room', async () => {
    await gateway.pushInbox(chatId);
    expect(emitted).toEqual([
      { room: `user:${me}`, event: 'inbox', payload: { chatId } },
      { room: `user:${peer}`, event: 'inbox', payload: { chatId } },
    ]);
  });
});
