import { ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { LineBotService } from './line-bot.service';

const SECRET = 'channel-secret-for-tests';
const USER = `U${'b'.repeat(32)}`;

const sign = (body: string, secret = SECRET) => createHmac('sha256', secret).update(body).digest('base64');
const env = (over: Record<string, string> = {}) => {
  const values: Record<string, string> = {
    LINE_CHANNEL_SECRET: SECRET,
    LINE_CHANNEL_ACCESS_TOKEN: 'access-token',
    LINE_FINDER_URL: 'https://app.example.test',
    ...over,
  };
  return { get: (key: string, fallback?: string) => values[key] ?? fallback } as unknown as ConfigService;
};

function setup(over: Record<string, string> = {}, status = 'bound') {
  const campus = { call: jest.fn(async () => ({ status, item_name: '', mine: false })) };
  const service = new LineBotService(env(over), campus as never);
  return { service, campus };
}

const found = JSON.stringify({ events: [{ type: 'postback', replyToken: 'rt', source: { type: 'user', userId: USER }, postback: { data: 'action=found' } }] });
const codeSent = JSON.stringify({ events: [{ type: 'message', replyToken: 'rc', source: { type: 'user', userId: USER }, message: { type: 'text', text: 'k7m2xq' } }] });
type Sent = { replyToken: string; messages: { text?: string; contents?: { footer: { contents: { action: { uri: string } }[] } } }[] };
const body = (mock: jest.SpyInstance, call = 0) => JSON.parse((mock.mock.calls[call] as [string, RequestInit])[1].body as string) as Sent;

describe('LineBotService.handleWebhook', () => {
  let fetchMock: jest.SpyInstance;
  beforeEach(() => {
    fetchMock = jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{}', { status: 200 }));
  });
  afterEach(() => fetchMock.mockRestore());

  it('is closed until the channel secret, access token and finder url are all set', async () => {
    for (const missing of ['LINE_CHANNEL_SECRET', 'LINE_CHANNEL_ACCESS_TOKEN', 'LINE_FINDER_URL']) {
      const { service, campus } = setup({ [missing]: '' });
      await expect(service.handleWebhook(Buffer.from(codeSent), sign(codeSent))).rejects.toBeInstanceOf(ServiceUnavailableException);
      expect(campus.call).not.toHaveBeenCalled();
    }
  });

  it('rejects a bad or missing signature before doing anything', async () => {
    const { service, campus } = setup();
    await expect(service.handleWebhook(Buffer.from(codeSent), sign(codeSent, 'wrong'))).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(service.handleWebhook(Buffer.from(codeSent), undefined)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(campus.call).not.toHaveBeenCalled();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('replies through the LINE reply API with the access token; the menu button opens the code entry page', async () => {
    const { service, campus } = setup();
    await service.handleWebhook(Buffer.from(found), sign(found));
    expect(campus.call).not.toHaveBeenCalled();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.line.me/v2/bot/message/reply');
    expect((init.headers as Record<string, string>).authorization).toBe('Bearer access-token');
    const sent = body(fetchMock);
    expect(sent.replyToken).toBe('rt');
    expect(sent.messages[0].contents?.footer.contents[0].action.uri).toBe('https://app.example.test/?src=line#/line/found');
  });

  it('checks a sent code with the public sticker lookup and links straight to its web page', async () => {
    const { service, campus } = setup();
    await service.handleWebhook(Buffer.from(codeSent), sign(codeSent));
    expect(campus.call).toHaveBeenCalledWith('sticker_lookup', { p_code: 'K7M2XQ' }, null);
    expect(body(fetchMock).messages[0].contents?.footer.contents[0].action.uri).toBe('https://app.example.test/q/K7M2XQ?src=line');
  });

  it('tells the finder when the code is unknown', async () => {
    const { service } = setup({}, 'unknown');
    await service.handleWebhook(Buffer.from(codeSent), sign(codeSent));
    expect(body(fetchMock).messages[0].text).toMatch(/找不到尋物碼 K7M2XQ/);
  });

  it('accepts LINE’s verify call (no events) and malformed bodies without replying', async () => {
    const { service } = setup();
    const verify = JSON.stringify({ destination: 'U1', events: [] });
    await service.handleWebhook(Buffer.from(verify), sign(verify));
    await service.handleWebhook(Buffer.from('not json'), sign('not json'));
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('keeps going when the LINE reply fails', async () => {
    fetchMock.mockResolvedValue(new Response('nope', { status: 500 }));
    const { service } = setup();
    await expect(service.handleWebhook(Buffer.from(found), sign(found))).resolves.toBeUndefined();
  });
});
