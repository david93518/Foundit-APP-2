import { NotFoundException } from '@nestjs/common';
import { ItemsService } from './items.service';

describe('ItemsService id handling', () => {
  it('treats a malformed id as missing instead of querying Postgres', async () => {
    const repo = { findOne: jest.fn() };
    const service = new ItemsService(repo as never);
    await expect(service.findOne('not-a-uuid')).rejects.toBeInstanceOf(NotFoundException);
    expect(repo.findOne).not.toHaveBeenCalled();
  });

  it('keyword matching without a source item does not compare against a fake id', async () => {
    const qb = {
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      getMany: jest.fn(async () => []),
    };
    const service = new ItemsService({ createQueryBuilder: () => qb } as never);
    await service.findForMatch(null, ['錢包']);
    const clauses = qb.andWhere.mock.calls.map((call) => String(call[0]));
    expect(clauses.some((clause) => clause.includes('item.id !='))).toBe(false);
  });
});
