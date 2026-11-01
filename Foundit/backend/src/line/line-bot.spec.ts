import { createHmac } from 'crypto';
import {
  CodeState,
  HELP,
  LineEvent,
  WELCOME,
  finderUrl,
  foundFlex,
  handleEvents,
  notFound,
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
    expect(stickerCodeIn('https://app.foundit.tw/q/K7M2XQ')).toBe('K7M2XQ');
    expect(stickerCodeIn('k7m2xq9a')).toBe('K7M2XQ9A');
    expect(stickerCodeIn('https://app.foundit.tw/q/K7M2XQ9A')).toBe('K7M2XQ9A');
  });

  it('rejects everything else', () => {
    expect(stickerCodeIn('K7M2XQ9')).toBe('');
    expect(stickerCodeIn('K7M2XQ9AB')).toBe('');
    expect(stickerCodeIn('我撿到東西')).toBe('');
    expect(stickerCodeIn('K7M2X0')).toBe('');
    expect(stickerCodeIn('')).toBe('');
    expect(stickerCodeIn(undefined)).toBe('');
  });
});

describe('finderUrl', () => {
  it('opens the web message page for a code, or the code entry page, tagged as coming from LINE', () => {
    expect(finderUrl(BASE, 'K7M2XQ')).toBe(`${BASE}/q/K7M2XQ?src=line`);
    expect(finderUrl(`${BASE}/`)).toBe(`${BASE}/?src=line#/line/found`);
  });
});

describe('foundFlex', () => {
  it('is a bubble with a body and one uri button, and says the finder stays anonymous', () => {
    const flex = foundFlex({ url: `${BASE}/x` }) as { contents: { type: string; footer: { contents: unknown[] } } };
    expect(flex.contents.type).toBe('bubble');
    expect(flex.contents.footer.contents).toHaveLength(1);
    expect(JSON.stringify(flex)).toMatch(/看不到你的 LINE/);
    expect(JSON.stringify(flex)).not.toMatch(/分鐘/);
  });
});

describe('handleEvents', () => {
  const user = { type: 'user', userId: USER };
  const postback = (data: string, extra: Partial<LineEvent> = {}): LineEvent => ({ type: 'postback', replyToken: 'r1', source: user, postback: { data }, ...extra });
  const text = (body: string, replyToken = 'r2'): LineEvent => ({ type: 'message', replyToken, source: user, message: { type: 'text', text: body } });

  async function run(events: LineEvent[], state: CodeState = 'bound') {
    const sent: { replyToken: string; messages: unknown[] }[] = [];
    const looked: string[] = [];
    await handleEvents(events, {
      finderBase: BASE,
      lookup: async (code) => {
        looked.push(code);
        return state;
      },
      reply: async (replyToken, messages) => {
        sent.push({ replyToken, messages });
      },
      log: () => undefined,
    });
    return { sent, looked };
  }
  type Flex = { type: string; altText: string; contents: { footer: { contents: { action: { type: string; uri: string } }[] } } };
  const uri = (sent: { messages: unknown[] }[]) => (sent[0].messages[0] as Flex).contents.footer.contents[0].action.uri;

  it('welcomes a new friend', async () => {
    const { sent, looked } = await run([{ type: 'follow', replyToken: 'r0', source: user }]);
    expect(sent).toEqual([{ replyToken: 'r0', messages: WELCOME }]);
    expect(looked).toEqual([]);
  });

  it('answers the found button with a Flex Message whose button opens the code entry page', async () => {
    const { sent, looked } = await run([postback('action=found')]);
    expect(looked).toEqual([]);
    expect(sent).toHaveLength(1);
    expect(sent[0].replyToken).toBe('r1');
    const flex = sent[0].messages[0] as Flex;
    expect(flex.type).toBe('flex');
    expect(flex.altText.length).toBeLessThanOrEqual(400);
    expect(flex.contents.footer.contents[0].action.type).toBe('uri');
    expect(uri(sent)).toBe(`${BASE}/?src=line#/line/found`);
    expect(JSON.stringify(sent)).not.toContain(USER);
  });

  it('sends a known finder code straight to that person\'s web message page', async () => {
    const { sent, looked } = await run([text('k7m2xq')]);
    expect(looked).toEqual(['K7M2XQ']);
    expect(uri(sent)).toBe(`${BASE}/q/K7M2XQ?src=line`);
    expect(JSON.stringify(sent[0].messages[0])).toMatch(/K7M2XQ 已經找到物主/);
  });

  it('says so when the code does not exist or was replaced', async () => {
    const { sent } = await run([text('K7M2XQ')], 'unknown');
    expect(sent).toEqual([{ replyToken: 'r2', messages: notFound('K7M2XQ') }]);
  });

  it('offers an unclaimed blank sticker to whoever holds it, and tells a finder to use a lost-and-found desk', async () => {
    const { sent, looked } = await run([text('K7M2XQ')], 'unbound');
    expect(looked).toEqual(['K7M2XQ']);
    expect(uri(sent)).toBe(`${BASE}/q/K7M2XQ?src=line`);
    const body = JSON.stringify(sent[0].messages[0]);
    expect(body).toMatch(/K7M2XQ 還沒有主人/);
    expect(body).toMatch(/認領這張貼紙/);
    expect(body).toMatch(/招領站/);
  });

  it('points other text to the menu and ignores other postbacks and events', async () => {
    const other = await run([text('你好', 'r3')]);
    expect(other.sent).toEqual([{ replyToken: 'r3', messages: HELP }]);
    expect(other.looked).toEqual([]);
    expect((await run([postback('action=other')])).sent).toEqual([]);
    expect((await run([{ type: 'unfollow', source: user }, { type: 'message', replyToken: 'r4', message: { type: 'image' } }])).sent).toEqual([]);
  });

  it('turns groups away', async () => {
    const group = await run([postback('action=found', { source: { type: 'group', userId: USER } })]);
    expect(JSON.stringify(group.sent[0].messages)).toMatch(/1 對 1/);
  });

  it('skips redelivered events, and one failing event does not stop the others', async () => {
    const redelivered = await run([postback('action=found', { deliveryContext: { isRedelivery: true } })]);
    expect(redelivered).toEqual({ sent: [], looked: [] });

    const logged: string[] = [];
    const replied: string[] = [];
    await handleEvents([text('K7M2XQ'), { type: 'follow', replyToken: 'r9' }], {
      finderBase: BASE,
      lookup: async () => {
        throw new Error('database down');
      },
      reply: async (replyToken) => {
        replied.push(replyToken);
      },
      log: (...args) => logged.push(args.join(' ')),
    });
    expect(replied).toEqual(['r9']);
    expect(logged[0]).toMatch(/database down/);
  });
});
