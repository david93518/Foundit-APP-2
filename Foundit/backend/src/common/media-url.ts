import { ConfigService } from '@nestjs/config';
import { createHmac, randomUUID, timingSafeEqual } from 'crypto';

type ConfigReader = Pick<ConfigService, 'get'> | undefined;

function read(config: ConfigReader, key: string): string | undefined {
  return config ? config.get<string>(key) : process.env[key];
}

/** 圖片與 QR 網址的公開來源。正式環境沒有設定 APP_BASE_URL 時回傳 null，由呼叫端拒絕。 */
export function publicBaseUrl(config: ConfigReader): string | null {
  const configured = read(config, 'APP_BASE_URL')?.trim().replace(/\/$/, '');
  if (configured) return configured;
  if (read(config, 'NODE_ENV') === 'production') return null;
  return `http://127.0.0.1:${read(config, 'PORT') ?? '3000'}`;
}

/** 簽上傳檔名用的金鑰；沒有另外設定時沿用 JWT_SECRET（啟動時已檢查過強度）。 */
export function uploadSecret(config: ConfigReader): string {
  return read(config, 'UPLOAD_SIGNING_SECRET')?.trim() || read(config, 'JWT_SECRET')?.trim() || '';
}

const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
/** 新格式：<檔案 uuid>_<HMAC(使用者, 檔案)>.jpg。網址看不出是誰上傳，同一人的檔案之間也無法串連。 */
const SIGNED_NAME = new RegExp(`^(${UUID})_([0-9a-f]{32})\\.jpg$`);
/** 舊格式：<使用者 uuid>_<檔案 uuid>.jpg，直接暴露上傳者帳號；只為了已經存在的檔案保留辨識。 */
const LEGACY_NAME = new RegExp(`^(${UUID})_${UUID}\\.jpg$`, 'i');

function mac(secret: string, userId: string, fileId: string): string {
  return createHmac('sha256', secret).update(`upload:${userId.toLowerCase()}:${fileId}`).digest('hex').slice(0, 32);
}

export function newUploadName(userId: string, secret: string): string {
  if (!secret) throw new Error('缺少上傳簽章金鑰');
  const fileId = randomUUID();
  return `${fileId}_${mac(secret, userId, fileId)}.jpg`;
}

/** 檔名是否屬於 userId（新格式驗 HMAC，舊格式比對前綴）。 */
export function isOwnUploadName(name: string, userId: string, secret: string): boolean {
  const signed = SIGNED_NAME.exec(name);
  if (signed) {
    if (!secret) return false;
    const expected = Buffer.from(mac(secret, userId, signed[1]));
    const given = Buffer.from(signed[2]);
    return expected.length === given.length && timingSafeEqual(expected, given);
  }
  const legacy = LEGACY_NAME.exec(name);
  return legacy != null && legacy[1].toLowerCase() === userId.toLowerCase();
}

function parse(value: unknown): URL | null {
  if (typeof value !== 'string' || value.length > 500) return null;
  try {
    const url = new URL(value);
    if (url.username || url.password || url.search || url.hash) return null;
    return url;
  } catch {
    return null;
  }
}

/**
 * 只接受本站 /uploads/ 底下、由 userId 本人上傳的圖片。
 * 刊登照片、頭像與聊天圖片若能填任意網址，其他使用者的 App 載入時就會把 IP 與瀏覽行為送給第三方。
 */
export function isOwnUpload(value: unknown, userId: string, base: string | null, secret: string): boolean {
  const url = parse(value);
  const origin = base ? parse(base) : null;
  if (!url || !origin || url.origin !== origin.origin) return false;
  const prefix = `${origin.pathname.replace(/\/$/, '')}/uploads/`;
  if (!url.pathname.startsWith(prefix)) return false;
  return isOwnUploadName(url.pathname.slice(prefix.length), userId, secret);
}

/** Google 登入帶來的大頭貼。 */
export function isGoogleAvatar(value: unknown): boolean {
  const url = parse(value);
  return url != null && url.protocol === 'https:' && /(^|\.)googleusercontent\.com$/i.test(url.hostname);
}
