import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ItemsService } from './items.service';
import { Item, ItemStatus } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { newUploadName } from '../common/media-url';

const ITEM_ID = '6c628b21-c68a-45c5-96a0-558ccf344819';

describe('ItemsService.update whitelist', () => {
  it('does not apply id, owner or status from the request', async () => {
    const item = {
      id: ITEM_ID,
      userId: 'owner',
      status: ItemStatus.ACTIVE,
      title: '舊標題',
      hiddenAt: null,
    } as Item;
    const repo = {
      findOne: jest.fn(async () => item),
      update: jest.fn(async (_where: unknown, _data: unknown) => ({ affected: 1 })),
    };
    const service = new ItemsService(repo as never);
    const saved = await service.update(ITEM_ID, {
      title: '新標題',
      id: 'other',
      userId: 'intruder',
      status: ItemStatus.RESOLVED,
    } as never, { id: 'owner' } as User);

    expect(saved.id).toBe(ITEM_ID);
    expect(saved.userId).toBe('owner');
    expect(saved.status).toBe(ItemStatus.ACTIVE);
    expect(saved.title).toBe('新標題');
    expect(repo.update.mock.calls[0][1]).toEqual({ title: '新標題' });
  });

  it('rejects an edit from another account', async () => {
    const repo = {
      findOne: jest.fn(async () => ({ id: ITEM_ID, userId: 'owner' })),
      save: jest.fn(),
    };
    const service = new ItemsService(repo as never);
    await expect(service.update(ITEM_ID, { title: 'x' }, { id: 'other' } as User)).rejects.toBeInstanceOf(ForbiddenException);
    expect(repo.save).not.toHaveBeenCalled();
  });
});

describe('Listing lifecycle and ownership', () => {
  const make = (changes: Partial<Item> = {}) => {
    const item = {id: ITEM_ID, userId: 'owner', status: ItemStatus.ACTIVE, hiddenAt: null, ...changes} as Item;
    const repo = {findOne: jest.fn(async () => item), update: jest.fn(async (_where: unknown, _data: unknown) => ({affected: 1})), find: jest.fn(async (_options: any) => [])};
    return {item, repo, service: new ItemsService(repo as never)};
  };
  it('rejects deletion by another user without touching the listing', async () => {
    const {repo, service} = make();
    await expect(service.remove(ITEM_ID, {id: 'other'} as User)).rejects.toBeInstanceOf(ForbiddenException);
    expect(repo.update).not.toHaveBeenCalled();
  });
  it('removes visibility while keeping the item ID for existing chats', async () => {
    const {repo, service} = make();
    await service.remove(ITEM_ID, {id: 'owner'} as User);
    expect(repo.update).toHaveBeenCalledWith({id: ITEM_ID, userId: 'owner'}, {status: ItemStatus.CLOSED, hiddenAt: expect.any(Date)});
  });
  it('does not let an owner read, edit or resolve a deleted listing', async () => {
    const {repo, service} = make({status: ItemStatus.CLOSED, hiddenAt: new Date()});
    await expect(service.findOne(ITEM_ID, 'owner')).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.update(ITEM_ID, {title: 'restore'}, {id: 'owner'} as User)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.resolve(ITEM_ID, {id: 'owner'} as User)).rejects.toBeInstanceOf(NotFoundException);
    expect(repo.update).not.toHaveBeenCalled();
  });
  it('refuses to overwrite a listing deleted while an edit was in flight', async () => {
    const {repo, service} = make();
    repo.update.mockResolvedValue({affected: 0});
    await expect(service.update(ITEM_ID, {title: 'new'}, {id: 'owner'} as User)).rejects.toBeInstanceOf(BadRequestException);
    expect(repo.update.mock.calls[0][0]).toMatchObject({id: ITEM_ID, userId: 'owner', status: ItemStatus.ACTIVE});
    expect(repo.update.mock.calls[0][1]).toEqual({title: 'new'});
  });
  it('excludes removed listings from the owner collection', async () => {
    const {repo, service} = make();
    await service.findByUser('owner');
    expect(repo.find.mock.calls[0][0].where.hiddenAt.type).toBe('isNull');
  });
});

describe('ItemsService image sources', () => {
  const OWNER = '6c628b21-c68a-45c5-96a0-558ccf344819';
  const OTHER = '11111111-1111-4111-8111-111111111111';
  const FILE = '22222222-2222-4222-8222-222222222222';
  const settings: Record<string, string> = { APP_BASE_URL: 'https://api.foundit.tw', JWT_SECRET: 'test-secret-test-secret-test-secret' };
  const config = { get: (key: string) => settings[key] };
  const mine = `https://api.foundit.tw/uploads/${newUploadName(OWNER, settings.JWT_SECRET)}`;
  const theirs = `https://api.foundit.tw/uploads/${OTHER}_${FILE}.jpg`;

  it('only lets new images point at the poster’s own uploads', async () => {
    const legacy = 'https://images.example.com/old.jpg';
    const item = { id: ITEM_ID, userId: OWNER, status: ItemStatus.ACTIVE, hiddenAt: null, images: [legacy] } as unknown as Item;
    const repo = { findOne: jest.fn(async () => item), update: jest.fn(async () => ({ affected: 1 })) };
    const service = new ItemsService(repo as never, undefined, config as never);
    const owner = { id: OWNER } as User;
    await expect(service.update(ITEM_ID, { images: [legacy, mine] }, owner)).resolves.toBeDefined();
    await expect(service.update(ITEM_ID, { images: [theirs] }, owner)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.update(ITEM_ID, { images: ['https://tracker.example/p.gif'] }, owner))
      .rejects.toBeInstanceOf(BadRequestException);
  });
});
