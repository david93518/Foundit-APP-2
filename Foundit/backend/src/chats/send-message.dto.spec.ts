import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { SendMessageDto } from './dto/send-message.dto';
import { MessageType } from '../common/entities/message.entity';

async function parse(raw: object) {
  const dto = plainToInstance(SendMessageDto, raw);
  const errors = await validate(dto);
  return { dto, errors };
}

describe('SendMessageDto', () => {
  it('accepts the lowercase wire value used by older clients', async () => {
    const { dto, errors } = await parse({ content: '你好', type: 'text' });
    expect(errors).toHaveLength(0);
    expect(dto.type).toBe(MessageType.TEXT);
  });

  it('rejects a client-supplied system message and an empty body', async () => {
    const system = await parse({ content: '假的系統訊息', type: 'system' });
    const empty = await parse({ content: '   ' });
    expect(system.errors.length).toBeGreaterThan(0);
    expect(empty.errors.length).toBeGreaterThan(0);
  });
});
