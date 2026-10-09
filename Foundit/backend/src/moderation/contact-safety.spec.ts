import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ModerationService } from './moderation.service';
import { User } from '../common/entities/user.entity';

const me = '22222222-2222-4222-8222-222222222222';
const peer = '33333333-3333-4333-8333-333333333333';
const actor = { id: me, status: 'active' } as User;
function setup() {
  const reports = { create: jest.fn(v => v), save: jest.fn(async v => v) };
  const blocks = { find: jest.fn(async () => [{ blockerId: me, blockedId: peer, createdAt: new Date(0) }]),
    findOne: jest.fn(async () => null), upsert: jest.fn(), delete: jest.fn() };
  const users = { findOne: jest.fn(async () => ({ id: peer })),
    find: jest.fn(async () => [{ id: peer, name: '小林', avatarUrl: '', status: 'active' }]) };
  const service = new ModerationService(reports as any, blocks as any, {} as any, users as any, {} as any, {} as any);
  return { service, reports, blocks, users };
}

describe('contact safety', () => {
  it('returns only own block list with public names and no contact credentials', async () => {
    const { service, blocks, users } = setup();
    const rows = await service.blockSummaries(me);
    expect(blocks.find).toHaveBeenCalledWith({ where: { blockerId: me }, order: { createdAt: 'DESC' } });
    expect(users.find).toHaveBeenCalledWith(expect.objectContaining({ select: ['id', 'name', 'avatarUrl', 'status'] }));
    expect(rows[0]).toEqual({ user_id: peer, name: '小林', avatar_url: '', created_at: new Date(0) });
    users.find.mockResolvedValueOnce([{ id: peer, name: '私人名字', avatarUrl: 'old', status: 'deleted' }]);
    expect((await service.blockSummaries(me))[0]).toMatchObject({ name: '已刪除的帳號', avatar_url: '' });
  });
  it('unblock is scoped to the caller and validates the id', async () => {
    const { service, blocks } = setup();
    await service.unblock(me, peer);
    expect(blocks.delete).toHaveBeenCalledWith({ blockerId: me, blockedId: peer });
    await expect(service.unblock(me, 'bad')).rejects.toBeInstanceOf(BadRequestException);
    expect(blocks.delete).toHaveBeenCalledTimes(1);
  });
  it('blocks idempotently, but rejects self and unknown users', async () => {
    const { service, blocks, users } = setup();
    await service.block(actor, peer);
    expect(blocks.upsert).toHaveBeenCalledWith({ blockerId: me, blockedId: peer }, ['blockerId', 'blockedId']);
    await expect(service.block(actor, me)).rejects.toBeInstanceOf(BadRequestException);
    users.findOne.mockResolvedValueOnce(null as any);
    await expect(service.block(actor, peer)).rejects.toBeInstanceOf(NotFoundException);
  });
  it('reports actual other users only, persisting a trimmed reason', async () => {
    const { service, reports, users } = setup();
    const dto = { targetType: 'user' as const, targetId: peer, reason: ' 疑似詐騙 ' };
    await service.report(actor, dto);
    expect(reports.save).toHaveBeenCalledWith(expect.objectContaining({ reporterId: me, targetId: peer, reason: '疑似詐騙', status: 'open' }));
    await expect(service.report(actor, { ...dto, targetId: me })).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.report(actor, { ...dto, targetId: 'bad' })).rejects.toBeInstanceOf(BadRequestException);
    users.findOne.mockResolvedValueOnce(null as any);
    await expect(service.report(actor, dto)).rejects.toBeInstanceOf(NotFoundException);
    expect(reports.save).toHaveBeenCalledTimes(1);
  });
});
