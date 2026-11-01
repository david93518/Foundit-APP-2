import { createHmac, timingSafeEqual } from 'crypto';

// LINE 官方帳號 webhook 的邏輯。不碰網路也不碰資料庫，方便單元測試；LineBotService 把它接到 LINE 和資料庫。

/** 連結有效多久。實際期限由資料庫記錄；這裡只決定訊息上寫的數字。 */
export const LINK_MINUTES = 60;

export type LineMessage = Record<string, unknown>;

export interface LineEvent {
  type?: string;
  replyToken?: string;
  source?: { type?: string; userId?: string };
  message?: { type?: string; text?: string };
  postback?: { data?: string };
  deliveryContext?: { isRedelivery?: boolean };
}

export interface BotDeps {
  /** 替這位 LINE 使用者發一個撿到東西用的連結；問太頻繁時丟 RateLimitedError。 */
  issueLink(lineUserId: string, minutes: number): Promise<string>;
  reply(replyToken: string, messages: LineMessage[]): Promise<void>;
  /** 撿到東西頁面的網址，例如 https://foundit-webapp.vercel.app */
  finderBase: string;
  log?: (...args: unknown[]) => void;
}

export class RateLimitedError extends Error {
  constructor() {
    super('rate limited');
  }
}

const text = (body: string): LineMessage => ({ type: 'text', text: body });

export const WELCOME = [
  text(
    '歡迎使用 FOUND !T 找得到 👋\n\n' +
      '東西不見了？點下面的「東西不見了」，寫下特徵就能發佈尋物。\n' +
      '撿到東西？點「我撿到東西了」，不用登入就能通知失主。\n' +
      '手上有我們發的貼紙？貼在常帶的東西上，被撿到時你會收到通知。',
  ),
];
export const HELP = [text('請用下面的選單：\n「東西不見了」發佈尋物，「我撿到東西了」通知失主。\n如果你手上有貼紙，也可以直接把貼紙上的 6 碼編號傳給我。')];
export const TOO_MANY = [text('你剛剛已經要了很多次連結，請過一小時再試。')];
export const GROUP_ONLY = [text('請在和官方帳號的 1 對 1 聊天室使用。')];

// 貼紙編號：6 碼，沒有 0、O、1、I（見 qr/sticker-code.ts，同一組字元）。
const CODE = /^[A-HJ-NP-Z2-9]{6}$/;

/** 從使用者輸入或貼上的內容找貼紙編號（可以是編號本身，或 /qr/編號 的網址）；找不到回傳空字串。 */
export function stickerCodeIn(raw: unknown): string {
  const value = String(raw ?? '').trim();
  const link = value.match(/(?:^|[/#])qr?\/([A-Za-z0-9]{6})(?:$|[?#/\s])/);
  const code = (link ? link[1] : value).toUpperCase();
  return CODE.test(code) ? code : '';
}

/** LINE 用頻道密鑰對「原始」請求內容做 HMAC-SHA256，base64 後放在 x-line-signature。 */
export function verifySignature(body: Buffer | string, signature: string | undefined, secret: string | undefined): boolean {
  if (!secret || !signature) return false;
  const expected = createHmac('sha256', secret).update(body).digest();
  const given = Buffer.from(signature, 'base64');
  return given.length === expected.length && timingSafeEqual(given, expected);
}

/** 連結打開的頁面。`src=line` 讓流量來源統計看得到。 */
export function finderUrl(base: string, token: string, code = ''): string {
  const root = String(base).replace(/\/+$/, '');
  return `${root}/?src=line#/line/found?t=${encodeURIComponent(token)}${code ? `&c=${encodeURIComponent(code)}` : ''}`;
}

/** 帶連結的訊息。打開它不需要登入，也不需要 App。 */
export function foundFlex({ url, minutes = LINK_MINUTES, code = '' }: { url: string; minutes?: number; code?: string }): LineMessage {
  return {
    type: 'flex',
    altText: '通知失主：點這裡填寫',
    contents: {
      type: 'bubble',
      body: {
        type: 'box',
        layout: 'vertical',
        spacing: 'md',
        contents: [
          { type: 'text', text: '撿到東西了嗎？', weight: 'bold', size: 'lg' },
          {
            type: 'text',
            text: code
              ? `貼紙編號 ${code} 已經填好，只要留一句話，失主就會收到通知。`
              : '輸入貼紙上的 6 碼編號並留一句話，失主就會收到通知。',
            wrap: true,
            size: 'sm',
            color: '#555555',
          },
          { type: 'text', text: '不用登入，失主也看不到你的 LINE。', wrap: true, size: 'sm', color: '#555555' },
          { type: 'text', text: `連結 ${minutes} 分鐘內有效`, size: 'xs', color: '#888888' },
        ],
      },
      footer: {
        type: 'box',
        layout: 'vertical',
        contents: [{ type: 'button', style: 'primary', action: { type: 'uri', label: '通知失主', uri: url } }],
      },
    },
  };
}

/**
 * 處理一次 webhook 呼叫裡的所有事件。一個事件失敗只記錄、跳過，
 * 不會讓整批事件都失敗。
 */
export async function handleEvents(events: LineEvent[] | undefined, deps: BotDeps): Promise<void> {
  const log = deps.log ?? ((...args: unknown[]) => console.error(...args));
  for (const event of events ?? []) {
    // 重送的事件早就回過了，再處理只會多發一個連結。
    if (event?.deliveryContext?.isRedelivery) continue;
    try {
      await handleEvent(event, deps);
    } catch (error) {
      log('line event failed:', event?.type, error instanceof Error ? error.message : String(error));
    }
  }
}

async function handleEvent(event: LineEvent, deps: BotDeps): Promise<void> {
  const replyToken = event?.replyToken;
  if (!replyToken) return;
  if (event.type === 'follow') return deps.reply(replyToken, WELCOME);
  if (event.type === 'postback') {
    const action = new URLSearchParams(String(event.postback?.data ?? '')).get('action');
    if (action === 'found') return sendFoundLink(event, replyToken, deps, '');
    return;
  }
  if (event.type === 'message' && event.message?.type === 'text') {
    const code = stickerCodeIn(event.message.text);
    return code ? sendFoundLink(event, replyToken, deps, code) : deps.reply(replyToken, HELP);
  }
}

async function sendFoundLink(event: LineEvent, replyToken: string, deps: BotDeps, code: string): Promise<void> {
  const userId = event.source?.userId;
  if (event.source?.type !== 'user' || !userId) return deps.reply(replyToken, GROUP_ONLY);
  let token: string;
  try {
    token = await deps.issueLink(userId, LINK_MINUTES);
  } catch (error) {
    if (error instanceof RateLimitedError) return deps.reply(replyToken, TOO_MANY);
    throw error;
  }
  return deps.reply(replyToken, [foundFlex({ url: finderUrl(deps.finderBase, token, code), minutes: LINK_MINUTES, code })]);
}
