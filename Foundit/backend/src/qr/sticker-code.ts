import { randomInt } from 'crypto';

/** 去掉容易看錯的 I、O、0、1。LINE webhook 的辨識規則（line-webhook handler）用的是同一組字元。 */
export const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
/** 32^6 約 10 億種。夠用，靠 LINE 連結的次數與頻率限制擋猜碼。 */
export const CODE_LENGTH = 6;

export function newStickerCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i += 1) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return code;
}

/**
 * 接受貼在輸入框的編號或整串貼紙網址。6 碼新編號不分大小寫；舊的 UUID 編號（8 碼以上、可含連字號）保持原樣。
 * 格式不對回傳 null。
 */
export function normalizeCode(raw: string): string | null {
  let value = String(raw ?? '').trim();
  const fromUrl = value.match(/\/(?:qr|q)\/([A-Za-z0-9-]{6,80})\/?(?:[?#].*)?$/);
  if (fromUrl) value = fromUrl[1];
  if (/^[A-Za-z0-9]{6}$/.test(value)) return value.toUpperCase();
  return /^[A-Za-z0-9-]{8,80}$/.test(value) ? value : null;
}
