import { DataSource, Repository, SelectQueryBuilder } from 'typeorm';
import { ItemsService } from './items.service';
import { Item, ItemType } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { Chat } from '../common/entities/chat.entity';
import { Message } from '../common/entities/message.entity';
import { Notification } from '../common/entities/notification.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { PointEvent } from '../common/entities/point-event.entity';

/** Build real PostgreSQL queries without connecting to or mutating a database. */
class MetadataOnlyDataSource extends DataSource {
  loadMetadata(): Promise<void> {
    return this.buildMetadatas();
  }
}

describe('ItemsService area filter', () => {
  let source: MetadataOnlyDataSource;
  let repository: Repository<Item>;
  let query: SelectQueryBuilder<Item>;
  let service: ItemsService;

  beforeAll(async () => {
    source = new MetadataOnlyDataSource({
      type: 'postgres',
      entities: [Item, User, Chat, Message, Notification, QrItem, UserPoints, PointEvent],
    });
    await source.loadMetadata();
  });

  beforeEach(() => {
    repository = source.getRepository(Item);
    query = repository.createQueryBuilder('item');
    jest.spyOn(query, 'getManyAndCount').mockResolvedValue([[], 0]);
    jest.spyOn(repository, 'createQueryBuilder').mockReturnValue(query);
    service = new ItemsService(repository);
  });

  afterEach(() => jest.restoreAllMocks());

  it('combines the selected city with item type and uses the actual location column', async () => {
    await service.findAll({ area: ' 臺北市 ', type: ItemType.FOUND });
    const [sql, parameters] = query.getQueryAndParameters();

    expect(sql).toContain('"item"."type" =');
    expect(sql).toContain('STRPOS(REPLACE("item"."location_name",');
    expect(sql).not.toContain('item.locationName');
    expect(parameters).toEqual(['ACTIVE', 'FOUND', '台北市']);
  });

  it.each([undefined, '', '  ', '全部地區'])('does not restrict area for %p', async (area) => {
    await service.findAll({ area });
    const [sql, parameters] = query.getQueryAndParameters();

    expect(sql).not.toContain('STRPOS');
    expect(parameters).toEqual(['ACTIVE']);
  });

  it('binds area literally and preserves pagination and result totals', async () => {
    jest.spyOn(query, 'getManyAndCount').mockResolvedValue([[], 25]);
    const result = await service.findAll({ area: '新北市_%', page: 2, page_size: 10 });
    const [sql, parameters] = query.getQueryAndParameters();

    expect(sql).not.toContain('新北市_%');
    expect(parameters).toContain('新北市_%');
    expect(query.expressionMap.skip).toBe(10);
    expect(query.expressionMap.take).toBe(10);
    expect(result).toEqual({ data: [], total: 25, hasMore: true });
  });

  it('searches the location name as well as the title and description', async () => {
    await service.findAll({ keyword: ' 臺北車站 ' });
    const [sql, parameters] = query.getQueryAndParameters();

    expect(sql).toContain('"item"."location_name"');
    expect(parameters).toContain('%台北車站%');
  });
});
