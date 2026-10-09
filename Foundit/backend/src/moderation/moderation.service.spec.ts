import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { ModerationService } from './moderation.service';
import { Report } from '../common/entities/report.entity';
import { Block } from '../common/entities/block.entity';
import { AdminAction } from '../common/entities/admin-action.entity';
import { User } from '../common/entities/user.entity';
import { Item, ItemStatus } from '../common/entities/item.entity';
import { ChatsGateway } from '../chats/chats.gateway';

const ITEM_ID = '6c628b21-c68a-45c5-96a0-558ccf344819';
const admin = { id: 'admin-1', role: 'admin', status: 'active' } as User;

function queryBuilder() {
  const where: string[] = [];
  const qb = {
    where,
    leftJoinAndSelect: jest.fn(),
    orderBy: jest.fn(),
    skip: jest.fn(),
    take: jest.fn(),
    andWhere: jest.fn(),
    getManyAndCount: jest.fn(async () => [[], 0]),
  };
  for (const key of ['leftJoinAndSelect', 'orderBy', 'skip', 'take'] as const) qb[key].mockReturnValue(qb);
  qb.andWhere.mockImplementation((clause: string) => {
    where.push(clause);
    return qb;
  });
  return qb;
}

function build(item?: Partial<Item>) {
  const actions = {
    create: jest.fn((row) => row),
    save: jest.fn(async (row) => row),
    find: jest.fn(),
    findOne: jest.fn(async () => ({ action: 'item.hide' })),
  };
  const items = {
    findOne: jest.fn(async () => (item ? { ...item } : null)),
    save: jest.fn(async (row) => row),
    createQueryBuilder: jest.fn(),
  };
  const users = { createQueryBuilder: jest.fn(), findOne: jest.fn(async () => ({ id: 'owner', status: 'active' })) };
  const service = new ModerationService(
    {} as Repository<Report>,
    {} as Repository<Block>,
    actions as unknown as Repository<AdminAction>,
    users as unknown as Repository<User>,
    items as unknown as Repository<Item>,
    { disconnectUser: jest.fn() } as unknown as ChatsGateway,
  );
  return { service, actions, items, users };
}

describe('ModerationService item moderation', () => {
  it('hides an item and writes an audit row', async () => {
    const { service, actions, items } = build({ id: ITEM_ID, status: ItemStatus.ACTIVE, hiddenAt: null });
    const saved = await service.hideItem(admin, ITEM_ID, '含個資');
    expect(saved.status).toBe(ItemStatus.CLOSED);
    expect(saved.hiddenAt).toBeInstanceOf(Date);
    expect(items.save).toHaveBeenCalledTimes(1);
    expect(actions.save).toHaveBeenCalledWith(expect.objectContaining({
      actorId: 'admin-1', action: 'item.hide', targetType: 'item', targetId: ITEM_ID, reason: '含個資', result: 'hidden',
    }));
  });

  it('restores a hidden item back to the public list', async () => {
    const { service, actions } = build({ id: ITEM_ID, status: ItemStatus.CLOSED, hiddenAt: new Date() });
    const saved = await service.restoreItem(admin, ITEM_ID, '誤判');
    expect(saved.status).toBe(ItemStatus.ACTIVE);
    expect(saved.hiddenAt).toBeNull();
    expect(actions.save).toHaveBeenCalledWith(expect.objectContaining({ action: 'item.restore', result: 'active' }));
  });

  it('refuses to republish a listing the owner removed or whose owner deleted the account', async () => {
    const removed = build({ id: ITEM_ID, userId: 'owner', status: ItemStatus.CLOSED, hiddenAt: new Date() });
    removed.actions.findOne.mockResolvedValueOnce(null as never);
    await expect(removed.service.restoreItem(admin, ITEM_ID, '誤判')).rejects.toBeInstanceOf(BadRequestException);
    const gone = build({ id: ITEM_ID, userId: 'owner', status: ItemStatus.CLOSED, hiddenAt: new Date() });
    gone.users.findOne.mockResolvedValueOnce({ id: 'owner', status: 'deleted' } as never);
    await expect(gone.service.restoreItem(admin, ITEM_ID, '誤判')).rejects.toBeInstanceOf(BadRequestException);
    expect(removed.items.save).not.toHaveBeenCalled();
    expect(gone.items.save).not.toHaveBeenCalled();
  });

  it('treats a malformed or unknown id as not found without touching the database', async () => {
    const { service, items, actions } = build();
    await expect(service.hideItem(admin, 'not-a-uuid', 'x')).rejects.toBeInstanceOf(NotFoundException);
    expect(items.findOne).not.toHaveBeenCalled();
    await expect(service.hideItem(admin, ITEM_ID, 'x')).rejects.toBeInstanceOf(NotFoundException);
    expect(actions.save).not.toHaveBeenCalled();
  });

  it('item list can be narrowed to hidden rows and never caps below one page', async () => {
    const { service, items } = build();
    const qb = queryBuilder();
    items.createQueryBuilder.mockReturnValue(qb);
    await service.listItems({ hidden: 'true', status: 'closed', q: ' 書 ', page: 0, page_size: 500 });
    expect(qb.where.some((c) => c.includes('hiddenAt IS NOT NULL'))).toBe(true);
    expect(qb.andWhere).toHaveBeenCalledWith('item.status = :status', { status: 'CLOSED' });
    expect(qb.andWhere).toHaveBeenCalledWith(expect.stringContaining('ILIKE :q'), { q: '%書%' });
    expect(qb.skip).toHaveBeenCalledWith(0);
    expect(qb.take).toHaveBeenCalledWith(100);
  });

  it('user list searches name, email and phone', async () => {
    const { service, users } = build();
    const qb = queryBuilder();
    users.createQueryBuilder.mockReturnValue(qb);
    await service.listUsers({ q: 'david', status: 'Suspended' });
    expect(qb.andWhere).toHaveBeenCalledWith(expect.stringContaining('user.email ILIKE :q'), { q: '%david%' });
    expect(qb.andWhere).toHaveBeenCalledWith('user.status = :status', { status: 'suspended' });
  });
});
