import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { BadRequestException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { CreateChatDto } from './dto/create-chat.dto';
import { ChatsService } from './chats.service';
import { toMobileChat } from './chat-mobile.serializer';
import { Chat } from '../common/entities/chat.entity';
import { Message } from '../common/entities/message.entity';
import { Item } from '../common/entities/item.entity';
import { Block } from '../common/entities/block.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';
import { QrService } from '../qr/qr.service';
import { ChatPushService } from './chat-push.service';

const CODE = '8f0c1f8e-2a3b-4c5d-9e6f-0a1b2c3d4e5f';

function user(id: string, name: string, status = 'active'): User {
  return { id, name, status, avatarUrl: '' } as User;
}

async function errorsFor(raw: object) {
  return validate(plainToInstance(CreateChatDto, raw));
}

describe('CreateChatDto', () => {
  it('accepts either a listed item or a scanned tag code', async () => {
    expect(await errorsFor({ item_id: CODE })).toHaveLength(0);
    expect(await errorsFor({ qr_code: CODE })).toHaveLength(0);
  });

  it('rejects an empty body and a malformed code', async () => {
    expect((await errorsFor({})).length).toBeGreaterThan(0);
    expect((await errorsFor({ qr_code: '../../etc' })).length).toBeGreaterThan(0);
  });
});

describe('ChatsService with a scanned tag', () => {
  const owner = user('11111111-1111-4111-8111-111111111111', '物主');
  const finder = user('22222222-2222-4222-8222-222222222222', '撿到的人');
  const tag = { id: '33333333-3333-4333-8333-333333333333', name: '藍色後背包' } as QrItem;
  let saved: unknown[];
  let service: ChatsService;
  let scanByCode: jest.Mock;
  let chatPush: { tagScanned: jest.Mock; newMessage: jest.Mock };

  beforeEach(() => {
    saved = [];
    scanByCode = jest.fn().mockResolvedValue({ qrItem: tag, owner });
    chatPush = { tagScanned: jest.fn().mockResolvedValue(undefined), newMessage: jest.fn() };
    const manager = {
      findOne: jest.fn().mockResolvedValue(null),
      create: (_: unknown, value: object) => ({ ...value }),
      save: jest.fn(async (value: object) => {
        saved.push(value);
        return { id: 'chat-1', ...value };
      }),
    };
    const chatRepo = {
      manager: { transaction: (work: (m: typeof manager) => unknown) => work(manager) },
      findOne: jest.fn().mockResolvedValue({ id: 'chat-1', qrItemId: tag.id, qrItem: tag, participants: [finder, owner] }),
    } as unknown as Repository<Chat>;
    const msgRepo = { find: jest.fn().mockResolvedValue([]) } as unknown as Repository<Message>;
    const blockRepo = { findOne: jest.fn().mockResolvedValue(null) } as unknown as Repository<Block>;
    service = new ChatsService(
      chatRepo,
      msgRepo,
      {} as Repository<Item>,
      blockRepo,
      { scanByCode } as unknown as QrService,
      chatPush as unknown as ChatPushService,
    );
  });

  it('opens a chat with the tag owner and records how it started', async () => {
    const chat = await service.createOrGet({ qr_code: CODE }, finder);

    expect(scanByCode).toHaveBeenCalledWith(CODE);
    expect(saved[0]).toMatchObject({ itemId: null, qrItemId: tag.id, requesterId: finder.id });
    expect((saved[0] as Chat).participants.map((p) => p.id)).toEqual([finder.id, owner.id]);
    expect(saved[1]).toMatchObject({ content: '撿到的人 掃描了防丟牌「藍色後背包」並發起聯絡' });
    expect(chatPush.tagScanned).toHaveBeenCalledWith(chat, finder, '藍色後背包');
    expect(toMobileChat(chat, finder.id)).toMatchObject({
      item_id: '',
      qr_item_id: tag.id,
      item_title: '藍色後背包',
      other_user_name: '物主',
    });
  });

  it('refuses the owner scanning their own tag and an inactive owner', async () => {
    await expect(service.createOrGet({ qr_code: CODE }, owner)).rejects.toThrow(BadRequestException);
    scanByCode.mockResolvedValue({ qrItem: tag, owner: user(owner.id, '物主', 'suspended') });
    await expect(service.createOrGet({ qr_code: CODE }, finder)).rejects.toThrow('無法聯絡這個物主');
    expect(saved).toHaveLength(0);
  });
});
