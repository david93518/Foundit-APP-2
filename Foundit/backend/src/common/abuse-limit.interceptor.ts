import {
  CallHandler, ExecutionContext, HttpException, HttpStatus, Injectable, NestInterceptor, SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { isIP } from 'net';
import { Observable } from 'rxjs';
import { clientIp } from './client-ip';

export interface RateRule {
  name: string;
  limit: number;
  windowMs: number;
  /** user：已登入者以帳號計，未登入退回來源 IP；ip：一律以來源 IP 計。 */
  by: 'user' | 'ip';
}

const RATE_LIMIT = 'foundit:rate-limit';

/**
 * 掛在路由處理函式上的限流規則。規則跟著處理函式走，而不是比對網址字串，
 * 所以大小寫不同、結尾多一個斜線等繞法都對應到同一組額度。
 */
export const RateLimit = (...rules: RateRule[]) => SetMetadata(RATE_LIMIT, rules);

interface Bucket {
  count: number;
  resetAt: number;
}

/** IPv6 以 /64 計，避免攻擊者在自己的網段裡輪換位址繞過額度。 */
export function limiterKeyForIp(ip: string): string {
  if (isIP(ip) !== 6) return ip;
  const [head, tail = ''] = ip.toLowerCase().split('::');
  const left = head ? head.split(':') : [];
  const right = tail ? tail.split(':') : [];
  const groups = ip.includes('::')
    ? [...left, ...Array<string>(Math.max(0, 8 - left.length - right.length)).fill('0'), ...right]
    : left;
  return `${groups.slice(0, 4).map((group) => group || '0').join(':')}::/64`;
}

@Injectable()
export class AbuseLimitInterceptor implements NestInterceptor {
  private readonly buckets = new Map<string, Bucket>();
  private nextSweep = 0;

  constructor(private readonly reflector: Reflector) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();
    const request = context.switchToHttp().getRequest<{
      headers?: Record<string, string | string[] | undefined>;
      socket?: { remoteAddress?: string };
      user?: { id?: string };
    }>();
    const response = context.switchToHttp().getResponse<{ setHeader?: (key: string, value: string) => void }>();
    const ip = limiterKeyForIp(clientIp(request));
    // 每個來源 IP 的總量上限在 main.ts 的最前面處理（守衛之前），這裡只管個別路由的規則。
    const rules = this.reflector.get<RateRule[]>(RATE_LIMIT, context.getHandler()) ?? [];
    if (rules.length === 0) return next.handle();
    const now = Date.now();
    this.sweep(now);
    for (const rule of rules) {
      const actor = rule.by === 'user' && request.user?.id ? `u:${request.user.id}` : `ip:${ip}`;
      const retryAfter = this.consume(`${rule.name}:${actor}`, rule, now);
      if (retryAfter > 0) {
        response.setHeader?.('Retry-After', String(Math.ceil(retryAfter / 1000)));
        throw new HttpException('操作太頻繁，請稍後再試', HttpStatus.TOO_MANY_REQUESTS);
      }
    }
    return next.handle();
  }

  /** 回傳 0 代表放行，否則是距離額度重置的毫秒數。 */
  private consume(key: string, rule: RateRule, now: number): number {
    const bucket = this.buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      this.buckets.set(key, { count: 1, resetAt: now + rule.windowMs });
      return 0;
    }
    bucket.count += 1;
    return bucket.count > rule.limit ? bucket.resetAt - now : 0;
  }

  /** 定期清掉過期的額度，記憶體不會隨來源數無限成長。 */
  private sweep(now: number): void {
    if (now < this.nextSweep) return;
    this.nextSweep = now + 60_000;
    for (const [key, bucket] of this.buckets) {
      if (bucket.resetAt <= now) this.buckets.delete(key);
    }
  }
}
