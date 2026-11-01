import { createHmac, timingSafeEqual } from 'crypto';

// LINE 官方帳號 webhook 的邏輯。不碰網路也不碰資料庫，方便單元測試；LineBotService 把它接到 LINE 和資料庫。

export type LineMessage = Record<string, unknown>;

export interface LineEvent {
  type?: string;
  replyToken?: string;
  source?: { type?: string; userId?: string };
  message?: { type?: string; text?: string };
  postback?: { data?: string };
  deliveryContext?: { isRedelivery?: boolean };
}

export type CodeState = 'bound' | 'unbound' | 'unknown';

export interface BotDeps {
  /** 這組尋物碼現在的狀態（網站的 sticker_lookup）。 */
  lookup(code: string): Promise<CodeState>;
  reply(replyToken: string, messages: LineMessage[]): Promise<void>;
  /** 網站的網址，例如 https://app.foundit.tw */
  finderBase: string;
  log?: (...args: unknown[]) => void;
}

const text = (body: string): LineMessage => ({ type: 'text', text: body });

export const WELCOME = [
  text(
    '歡迎使用 FOUND !T 找得到 👋\n\n' +
      '東西不見了？點下面的「東西不見了」，寫下特徵就能發佈尋物。\n' +
      '撿到東西？點「我撿到東西了」，不用登入就能通知失主。\n' +
      '手上有我們發的空白貼紙？用相機掃它、登入，它就是你的；貼在常帶的東西上，被撿到時你會收到通知。',
  ),
];
export const HELP = [text('請用下面的選單：\n「東西不見了」發佈尋物，「我撿到東西了」通知失主。\n撿到的東西上有 FOUND !T 的 6 碼尋物碼，也可以直接傳給我。')];
export const GROUP_ONLY = [text('請在和官方帳號的 1 對 1 聊天室使用。')];
export const notFound = (code: string): LineMessage[] => [
  text(`找不到尋物碼 ${code}。請再對一次東西上的 6 碼（英文和數字，沒有 0、O、1、I），或請物主到「我的貼紙」確認。`),
];

// 尋物碼：每人一組 6 碼，空白貼紙也是 6 碼；早期的一物一貼紙是 8 碼。沒有 0、O、1、I（與網站 campus_private.finder_code 同一組字元）。
const CODE = /^[A-HJ-NP-Z2-9]{6}(?:[A-HJ-NP-Z2-9]{2})?$/;

/** 從使用者輸入或貼上的內容找尋物碼（可以是碼本身，或 /q/碼 的網址）；找不到回傳空字串。 */
export function stickerCodeIn(raw: unknown): string {
  const value = String(raw ?? '').trim();
  const link = value.match(/(?:^|[/#])qr?\/([A-Za-z0-9]{6,8})(?:$|[?#/\s])/);
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

/** 有尋物碼時直接打開網站的留言頁；沒有時打開輸入尋物碼的頁面。`src=line` 讓流量來源統計看得到。 */
export function finderUrl(base: string, code = ''): string {
  const root = String(base).replace(/\/+$/, '');
  return code ? `${root}/q/${encodeURIComponent(code)}?src=line` : `${root}/?src=line#/line/found`;
}

/** 帶連結的訊息。打開它不需要登入，也不需要 App。 */
export function foundFlex({ url, code = '' }: { url: string; code?: string }): LineMessage {
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
              ? `尋物碼 ${code} 已經找到物主，點下面的按鈕留一句話，物主就會收到通知。`
              : '輸入東西上的 6 碼尋物碼並留一句話，物主就會收到通知。',
            wrap: true,
            size: 'sm',
            color: '#555555',
          },
          { type: 'text', text: '不用登入，物主也看不到你的 LINE；物主回覆後，你在同一個網頁就看得到。', wrap: true, size: 'sm', color: '#555555' },
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

/** 還沒有人認領的空白貼紙：拿到貼紙的人點進去登入就能認領；撿到東西的人請交招領站（沒有物主可以通知）。 */
export function unclaimedFlex({ url, code }: { url: string; code: string }): LineMessage {
  return {
    type: 'flex',
    altText: `貼紙 ${code} 還沒有主人`,
    contents: {
      type: 'bubble',
      body: {
        type: 'box',
        layout: 'vertical',
        spacing: 'md',
        contents: [
          { type: 'text', text: `貼紙 ${code} 還沒有主人`, weight: 'bold', size: 'lg', wrap: true },
          { type: 'text', text: '這是你拿到的空白貼紙嗎？點下面的按鈕登入，它就是你的了，有人撿到貼著它的東西時你會收到通知。', wrap: true, size: 'sm', color: '#555555' },
          { type: 'text', text: '如果是撿到的東西，貼紙還沒有人認領，沒辦法通知物主，請交給附近的招領站。', wrap: true, size: 'sm', color: '#555555' },
        ],
      },
      footer: {
        type: 'box',
        layout: 'vertical',
        contents: [{ type: 'button', style: 'primary', action: { type: 'uri', label: '認領這張貼紙', uri: url } }],
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
  if (event.source?.type !== 'user' || !event.source.userId) return deps.reply(replyToken, GROUP_ONLY);
  const state = code ? await deps.lookup(code) : 'bound';
  if (state === 'unknown') return deps.reply(replyToken, notFound(code));
  const url = finderUrl(deps.finderBase, code);
  return deps.reply(replyToken, [state === 'unbound' ? unclaimedFlex({ url, code }) : foundFlex({ url, code })]);
}
