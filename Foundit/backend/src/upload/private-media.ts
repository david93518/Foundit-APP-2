import { isOwnUploadName } from '../common/media-url';

export const PRIVATE_MEDIA_PATH = '/api/v1/upload/chat-images/';
export const PRIVATE_DIRECTORY = '.private';
export const SAFE_IMAGE_NAME = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?:_[0-9a-f-]{32,36})?\.jpg$/i;

export function privateImageName(value: unknown, base: string | null): string | null {
  if (typeof value !== 'string' || value.length > 500 || !base) return null;
  try {
    const url = new URL(value);
    const origin = new URL(base);
    if (url.origin !== origin.origin || url.username || url.password || url.search || url.hash ||
        !url.pathname.startsWith(PRIVATE_MEDIA_PATH)) return null;
    const name = url.pathname.slice(PRIVATE_MEDIA_PATH.length);
    return SAFE_IMAGE_NAME.test(name) ? name : null;
  } catch { return null; }
}

export function isOwnPrivateImage(value: unknown, userId: string, base: string | null, secret: string): boolean {
  const name = privateImageName(value, base);
  return name !== null && isOwnUploadName(name, userId, secret);
}
