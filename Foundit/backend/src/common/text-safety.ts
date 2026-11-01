import { Transform } from 'class-transformer';

/**
 * 會讓文字「看起來」和實際內容不同的字元：方向覆寫（例如把 "gpj.exe" 顯示成 "exe.jpg"）、
 * 零寬字元（讓「官方客服」中間藏一個看不見的字，躲過關鍵字比對）與控制字元。
 * 保留換行、Tab、表情符號用的零寬連接字（U+200D）與 U+200C。
 * 以碼位區間表示，原始碼裡不放任何看不見的字元。
 */
const INVISIBLE_RANGES: ReadonlyArray<readonly [number, number]> = [
  [0x00, 0x08], [0x0b, 0x0c], [0x0e, 0x1f], [0x7f, 0x9f], [0xad, 0xad], [0x61c, 0x61c],
  [0x200b, 0x200b], [0x200e, 0x200f], [0x202a, 0x202e], [0x2060, 0x2064], [0x2066, 0x2069],
  [0xfeff, 0xfeff],
];
/** U+2028／U+2029 與 CR 都當成換行。 */
const LINE_BREAKS = new Set([0x0d, 0x2028, 0x2029]);
const LF = 0x0a;
const TAB = 0x09;

function isInvisible(code: number): boolean {
  return INVISIBLE_RANGES.some(([from, to]) => code >= from && code <= to);
}

/** 清掉看不見的字元；單行欄位把換行與 Tab 收成一個空白。逐字元處理，不靠正規式跳脫。 */
export function cleanText(value: string, multiline = false): string {
  let text = '';
  let previous = -1;
  for (const char of value) {
    const code = char.codePointAt(0) ?? 0;
    const afterCr = previous === 0x0d;
    previous = code;
    if (code === LF && afterCr) continue;
    if (code === LF || code === TAB || LINE_BREAKS.has(code)) {
      const breakChar = code === TAB ? String.fromCharCode(TAB) : String.fromCharCode(LF);
      if (multiline) text += breakChar;
      else if (!text.endsWith(' ')) text += ' ';
      continue;
    }
    if (!isInvisible(code)) text += char;
  }
  return text.trim();
}

/** DTO 欄位用：驗證前先清掉看不見的字元，長度限制也以清理後為準。 */
export const CleanText = (multiline = false) =>
  Transform(({ value }) => (typeof value === 'string' ? cleanText(value, multiline) : value));

/**
 * 只有官方能用的名稱。聊天室裡的「FOUND !T 客服」是詐騙最常見的開場。
 * 中文詞直接比對；英文詞要求完整單字，避免把 badminton 這類名字誤擋。
 */
const RESERVED_CJK = ['官方', '客服', '管理員', '管理员', '系統', '系统', '版主', '站長', '站长'];
const RESERVED_WORDS = /(^|[^a-z0-9])(admin|administrator|official|support|system|moderator|staff)([^a-z0-9]|$)/;

export function isReservedName(name: string): boolean {
  const folded = cleanText(name).normalize('NFKC').toLowerCase();
  const squeezed = folded.replace(/[\s._\-·・|/\\]+/g, '');
  if (squeezed.includes('foundit') || squeezed.includes('found!t')) return true;
  if (RESERVED_CJK.some((word) => squeezed.includes(word))) return true;
  return RESERVED_WORDS.test(folded);
}

const TW_ID_LETTERS = 'ABCDEFGHJKLMNPQRSTUVXYWZIO';

/** 身分證／新式居留證字號，含檢查碼驗證，降低誤判。 */
function isTaiwanId(id: string): boolean {
  const n = TW_ID_LETTERS.indexOf(id[0]) + 10;
  if (n < 10) return false;
  const digits = [Math.floor(n / 10), n % 10, ...id.slice(1).split('').map(Number)];
  const weights = [1, 9, 8, 7, 6, 5, 4, 3, 2, 1, 1];
  return digits.reduce((sum, digit, index) => sum + digit * weights[index], 0) % 10 === 0;
}

function passesLuhn(number: string): boolean {
  let sum = 0;
  for (let i = 0; i < number.length; i += 1) {
    let digit = Number(number[number.length - 1 - i]);
    if (i % 2 === 1) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  return sum % 10 === 0;
}

/**
 * 公開刊登裡不該出現的個資：手機號碼、email、身分證／居留證字號、信用卡號。
 * 刊登規範已要求使用者不要公開這些資料，這裡在伺服器端再擋一次（聊天私訊不檢查）。
 */
export function findSensitiveData(...values: Array<string | null | undefined>): string | null {
  for (const value of values) {
    if (!value) continue;
    const text = value.normalize('NFKC');
    const squeezed = text.replace(/[\s\-().]/g, '').toUpperCase();
    if (/(?<!\d)(?:\+?886|0)9\d{8}(?!\d)/.test(squeezed)) return '手機號碼';
    if (/[^\s@<>()]+@[^\s@<>()]+\.[a-z]{2,}/i.test(text)) return 'email';
    for (const match of squeezed.matchAll(/(?<![A-Z0-9])[A-Z][1289]\d{8}(?!\d)/g)) {
      if (isTaiwanId(match[0])) return '身分證或居留證字號';
    }
    for (const match of squeezed.matchAll(/(?<!\d)\d{13,19}(?!\d)/g)) {
      if (passesLuhn(match[0])) return '卡號或序號';
    }
  }
  return null;
}
