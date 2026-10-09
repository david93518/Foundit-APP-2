import type { NextFunction, Request, Response } from 'express';

/** JSON API 與圖片都不需要執行任何腳本或被嵌進別人的頁面。 */
const API_CSP = "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'";
/** QR 落地頁只有一段內嵌樣式。 */
export const LANDING_CSP = "default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'";

export function securityHeaders(production: boolean) {
  return (req: Request, res: Response, next: NextFunction) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    // Swagger UI 只在開發環境或明確開啟時存在，它需要自己的腳本與樣式。
    if (!req.path.startsWith('/api/docs')) res.setHeader('Content-Security-Policy', API_CSP);
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
    // API 回應含個人資料（聊天、個人檔案）：不讓瀏覽器或中間的代理／CDN 快取。
    if (req.path.startsWith('/api/')) res.setHeader('Cache-Control', 'no-store');
    if (production) res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    next();
  };
}
