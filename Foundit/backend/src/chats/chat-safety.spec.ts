import { ForbiddenException } from '@nestjs/common';
import { ChatsService } from './chats.service';
import { User } from '../common/entities/user.entity';

const room = '11111111-1111-4111-8111-111111111111';
const me = '22222222-2222-4222-8222-222222222222';
const peer = '33333333-3333-4333-8333-333333333333';

function setup(member = true, blocked = false) {
  const qb: any = {};
  for (const method of ['innerJoin', 'where']) qb[method] = jest.fn(() => qb);
  qb.getCount = jest.fn(async () => member ? 1 : 0);
  const chats = { createQueryBuilder: () => qb,
    findOne: jest.fn(async () => ({ id: room, participants: [{ id: me }, { id: peer }] })) };
  const messages = { find: jest.fn(async () => []), save: jest.fn(), findOne: jest.fn() };
  const blocks = { findOne: jest.fn(async () => blocked ? { blockerId: peer, blockedId: me } : null) };
  const service = new ChatsService(chats as any, messages as any, {} as any, blocks as any, {} as any, {} as any);
  return { service, chats, messages, blocks };
}

describe('chat safety', () => {
  it('does not return chat participants to an outsider', async () => {
    const { service, chats } = setup(false);
    await expect(service.detailForUser(room, me)).rejects.toBeInstanceOf(ForbiddenException);
    expect(chats.findOne).not.toHaveBeenCalled();
  });
  it('allows participants to load their own chat details', async () => {
    const { service } = setup();
    expect((await service.detailForUser(room, me)).participants).toHaveLength(2);
  });
  it('rejects messaging when either party has blocked the other', async () => {
    const { service, messages, blocks } = setup(true, true);
    await expect(service.sendMessage(room, { content: 'hi' }, { id: me, status: 'active' } as User))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(blocks.findOne).toHaveBeenCalledWith({ where: [
      { blockerId: me, blockedId: peer }, { blockerId: peer, blockedId: me },
    ] });
    expect(messages.save).not.toHaveBeenCalled();
  });
});
