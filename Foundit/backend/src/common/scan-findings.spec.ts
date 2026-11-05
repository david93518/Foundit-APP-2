import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { DataSource, EntityManager } from 'typeorm';
import { CampusService } from '../campus/campus.service';
import { DisableQrDto } from '../qr/dto/qr-batch.dto';

// 2026-11-05 弱點掃描發現的兩個問題。

describe('station_list', () => {
  it('does not hand out the editor email the trigger stores in the station data', async () => {
    const queries: string[] = [];
    const manager = {
      query: jest.fn((sql: string) => {
        queries.push(sql);
        return Promise.resolve([]);
      }),
    } as unknown as EntityManager;
    const db = { transaction: (run: (m: EntityManager) => unknown) => run(manager) } as unknown as DataSource;
    await new CampusService(db).call('station_list', {}, null);
    expect(queries.at(-1)).toMatch(/data\s*-\s*'updatedByEmail'/);
  });
});

describe('DisableQrDto', () => {
  const errors = async (body: object) => validate(plainToInstance(DisableQrDto, body));

  it('checks batch_id even when a code is given too', async () => {
    expect(await errors({ code: 'ABCDEF', batch_id: 'John Doe' })).not.toHaveLength(0);
  });

  it('still accepts a code alone or a batch alone', async () => {
    expect(await errors({ code: 'ABCDEF' })).toHaveLength(0);
    expect(await errors({ batch_id: '6f75a1e3-7df0-4aac-80da-e0851dd6361b' })).toHaveLength(0);
    expect(await errors({})).not.toHaveLength(0);
  });
});
