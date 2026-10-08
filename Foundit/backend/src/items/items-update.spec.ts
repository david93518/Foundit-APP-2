import { ForbiddenException } from '@nestjs/common';
import { ItemsService } from './items.service';
import { Item, ItemStatus } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';

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
      save: jest.fn(async (value) => value),
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
