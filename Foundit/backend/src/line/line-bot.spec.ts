import { createHmac } from 'crypto';
import {
  HELP,
  LINK_MINUTES,
  LineEvent,
  RateLimitedError,
  TOO_MANY,
  WELCOME,
  finderUrl,
  foundFlex,
  handleEvents,
  stickerCodeIn,
  verifySignature,
} from './line-bot';

const SECRET = 'channel-secret-for-tests';
const USER = `U${'a'.repeat(32)}`;
const BASE = 'https://app.example.test';

describe('verifySignature', () => {
  const body = JSON.stringify({ events: [{ type: 'follow' }] });
  const good = createHmac('sha256', SECRET).update(body).digest('base64');

  it('accepts LINE’s HMAC and nothing else', () => {
    expect(verifySignature(body, good, SECRET)).toBe(true);
    expect(verifySignature(Buffer.from(body), good, SECRET)).toBe(true);
    expect(verifySignature(`${body} `, good, SECRET)).toBe(false);
    expect(verifySignature(body, good, 'other-secret')).toBe(false);
    expect(verifySignature(body, `${good.slice(0, -2)}AA`, SECRET)).toBe(false);
    expect(verifySignature(body, '', SECRET)).toBe(false);
    expect(verifySignature(body, undefined, SECRET)).toBe(false);
    expect(verifySignature(body, 'not base64 at all', SECRET)).toBe(false);
  });

  it('never verifies when the secret is unset', () => {
    const unsigned = createHmac('sha256', '').update(body).digest('base64');
    expect(verifySignature(body, unsigned, '')).toBe(false);
    expect(verifySignature(body, unsigned, undefined)).toBe(false);
  });
});

describe('stickerCodeIn', () => {
  it('finds a code in what people send', () => {
    expect(stickerCodeIn('k7m2xq')).toBe('K7M2XQ');
    expect(stickerCodeIn('  K7M2XQ \n')).toBe('K7M2XQ');
    expect(stickerCodeIn('https://api.foundit.tw/qr/K7M2XQ')).toBe('K7M2XQ');
    expect(stickerCodeIn('https://api.foundit.tw/q/K7M2XQ?x=1')).toBe('K7M2XQ');
  });

  it('rejects everything else', () => {
    expect(stickerCodeIn('K7M2XQ9A')).toBe('');
    expect(stickerCodeIn('我撿到東西')).toBe('');
    expect(stickerCodeIn('K7M2X0')).toBe('');
    expect(stickerCodeIn('')).toBe('');
    expect(stickerCodeIn(undefined)).toBe('');
  });
});

describe('finderUrl', () => {
  it('opens the finder page, tagged as coming from LINE', () => {
    expect(finderUrl(BASE, 'abc')).toBe(`${BASE}/?src=line#/line/found?t=abc`);
    expect(finderUrl(`${BASE}/`, 'abc', 'K7M2XQ')).toBe(`${BASE}/?src=line#/line/found?t=abc&c=K7M2XQ`);
  });
});

describe('foundFlex', () => {
  it('is a bubble with a body and one uri button', () => {
    const flex = foundFlex({ url: `${BASE}/x`, minutes: 30 }) as { contents: { type: string; footer: { contents: unknown[] } } };
    expect(flex.contents.type).toBe('bubble');
    expect(flex.contents.footer.contents).toHaveLength(1);
    expect(JSON.stringify(flex)).toMatch(/30 分鐘/);
  });
});

describe('handleEvents', () => {
  const user = { type: 'user', userId: USER };
  const postback = (data: string, extra: Partial<LineEvent> = {}): LineEvent => ({ type: 'postback', replyToken: 'r1', source: user, postback: { data }, ...extra });

  async function run(events: LineEvent[], issue?: (user: string) => Promise<string>) {
    const sent: { replyToken: string; messages: unknown[] }[] = [];
    const issued: [string, number][] = [];
    await handleEvents(events, {
      finderBase: BASE,
      issueLink: async (u, minutes) => {
        issued.push([u, minutes]);
        return issue ? issue(u) : 'tok123';
      },
      reply: async (replyToken, messages) => {
        sent.push({ replyToken, messages });
      },
      log: () => undefined,
    });
    return { sent, issued };
  }
  type Flex = { type: string; altText: string; contents: { footer: { contents: { action: { type: string; uri: string } }[] } } };

  it('welcomes a new friend', async () => {
    const { sent, issued } = await run([{ type: 'follow', replyToken: 'r0', source: user }]);
    expect(sent).toEqual([{ replyToken: 'r0', messages: WELCOME }]);
    expect(issued).toEqual([]);
  });

  it('answers “我撿到東西了” with a Flex Message whose button is the finder link', async () => {
    const { sent, issued } = await run([postback('action=found')]);
    expect(issued).toEqual([[USER, LINK_MINUTES]]);
    expect(sent).toHaveLength(1);
    expect(sent[0].replyToken).toBe('r1');
    const flex = sent[0].messages[0] as Flex;
    expect(flex.type).toBe('flex');
    expect(flex.altText.length).toBeLessThanOrEqual(400);
    const { action } = flex.contents.footer.contents[0];
    expect(action.type).toBe('uri');
    expect(action.uri).toBe(`${BASE}/?src=line#/line/found?t=tok123`);
    expect(action.uri.length).toBeLessThanOrEqual(1000);
    expect(JSON.stringify(flex)).toMatch(new RegExp(`${LINK_MINUTES} 分鐘`));
    expect(JSON.stringify(sent)).not.toContain(USER);
  });

  it('puts the code in the link when a sticker code is sent as text', async () => {
    const { sent } = await run([{ type: 'message', replyToken: 'r2', source: user, message: { type: 'text', text: 'k7m2xq' } }]);
    const flex = sent[0].messages[0] as Flex;
    expect(flex.contents.footer.contents[0].action.uri).toBe(`${BASE}/?src=line#/line/found?t=tok123&c=K7M2XQ`);
    expect(JSON.stringify(flex)).toMatch(/K7M2XQ 已經填好/);
  });

  it('points other text to the menu and ignores other postbacks and events', async () => {
    const text = await run([{ type: 'message', replyToken: 'r3', source: user, message: { type: 'text', text: '你好' } }]);
    expect(text.sent).toEqual([{ replyToken: 'r3', messages: HELP }]);
    expect((await run([postback('action=other')])).sent).toEqual([]);
    expect((await run([{ type: 'unfollow', source: user }, { type: 'message', replyToken: 'r4', message: { type: 'image' } }])).sent).toEqual([]);
  });

  it('tells a person who asked too often to wait, and turns groups away', async () => {
    const tooMany = await run([postback('action=found')], async () => {
      throw new RateLimitedError();
    });
    expect(tooMany.sent).toEqual([{ replyToken: 'r1', messages: TOO_MANY }]);
    const group = await run([postback('action=found', { source: { type: 'group', userId: USER } })]);
    expect(group.issued).toHaveLength(0);
    expect(JSON.stringify(group.sent[0].messages)).toMatch(/1 對 1/);
  });

  it('skips redelivered events, and one failing event does not stop the others', async () => {
    const redelivered = await run([postback('action=found', { deliveryContext: { isRedelivery: true } })]);
    expect(redelivered).toEqual({ sent: [], issued: [] });

    const logged: string[] = [];
    const replied: string[] = [];
    let attempts = 0;
    await handleEvents([postback('action=found'), { type: 'follow', replyToken: 'r9' }], {
      finderBase: BASE,
      issueLink: async () => {
        attempts += 1;
        throw new Error('database down');
      },
      reply: async (replyToken) => {
        replied.push(replyToken);
      },
      log: (...args) => logged.push(args.join(' ')),
    });
    expect(attempts).toBe(1);
    expect(replied).toEqual(['r9']);
    expect(logged[0]).toMatch(/database down/);
  });
});
