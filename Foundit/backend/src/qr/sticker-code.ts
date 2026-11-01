import { randomInt } from 'crypto';

/** 去掉容易看錯的 I、O、0、1。LINE webhook 的辨識規則（line-webhook handler）用的是同一組字元。 */
export const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const CODE_LENGTH = 8;

export function newStickerCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i += 1) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return code;
}

/**
 * 接受貼在輸入框的編號或整串貼紙網址。8 碼新編號不分大小寫；舊的 UUID 編號保持原樣。
 * 格式不對回傳 null。
 */
export function normalizeCode(raw: string): string | null {
  let value = String(raw ?? '').trim();
  const fromUrl = value.match(/\/(?:qr|q)\/([A-Za-z0-9-]{8,80})\/?(?:[?#].*)?$/);
  if (fromUrl) value = fromUrl[1];
  if (!/^[A-Za-z0-9-]{8,80}$/.test(value)) return null;
  return /^[A-Za-z0-9]{8}$/.test(value) ? value.toUpperCase() : value;
}
