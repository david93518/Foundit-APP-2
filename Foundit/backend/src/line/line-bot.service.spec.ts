import { HttpException, HttpStatus, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
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

function setup(over: Record<string, string> = {}, issue?: () => Promise<{ token: string }>) {
  const line = { issueLink: jest.fn(issue ?? (async () => ({ token: 'tok-1', expiresAt: new Date(), uses: 3 }))) };
  const service = new LineBotService(env(over), line as never);
  return { service, line };
}

const found = JSON.stringify({ events: [{ type: 'postback', replyToken: 'rt', source: { type: 'user', userId: USER }, postback: { data: 'action=found' } }] });

describe('LineBotService.handleWebhook', () => {
  let fetchMock: jest.SpyInstance;
  beforeEach(() => {
    fetchMock = jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{}', { status: 200 }));
  });
  afterEach(() => fetchMock.mockRestore());

  it('is closed until the channel secret, access token and finder url are all set', async () => {
    for (const missing of ['LINE_CHANNEL_SECRET', 'LINE_CHANNEL_ACCESS_TOKEN', 'LINE_FINDER_URL']) {
      const { service, line } = setup({ [missing]: '' });
      await expect(service.handleWebhook(Buffer.from(found), sign(found))).rejects.toBeInstanceOf(ServiceUnavailableException);
      expect(line.issueLink).not.toHaveBeenCalled();
    }
  });

  it('rejects a bad or missing signature before doing anything', async () => {
    const { service, line } = setup();
    await expect(service.handleWebhook(Buffer.from(found), sign(found, 'wrong'))).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(service.handleWebhook(Buffer.from(found), undefined)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(line.issueLink).not.toHaveBeenCalled();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('issues a link and replies through the LINE reply API with the access token', async () => {
    const { service, line } = setup();
    await service.handleWebhook(Buffer.from(found), sign(found));
    expect(line.issueLink).toHaveBeenCalledWith(USER, 60);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.line.me/v2/bot/message/reply');
    expect((init.headers as Record<string, string>).authorization).toBe('Bearer access-token');
    const sent = JSON.parse(init.body as string) as { replyToken: string; messages: { contents: { footer: { contents: { action: { uri: string } }[] } } }[] };
    expect(sent.replyToken).toBe('rt');
    expect(sent.messages[0].contents.footer.contents[0].action.uri).toBe('https://app.example.test/?src=line#/line/found?t=tok-1');
  });

  it('answers “too many” when the person is rate limited', async () => {
    const { service } = setup({}, async () => {
      throw new HttpException('操作太頻繁，請稍後再試', HttpStatus.TOO_MANY_REQUESTS);
    });
    await service.handleWebhook(Buffer.from(found), sign(found));
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(init.body as string).toMatch(/很多次連結/);
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
