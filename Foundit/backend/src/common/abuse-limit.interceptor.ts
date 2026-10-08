import { CallHandler, ExecutionContext, HttpException, HttpStatus, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';

interface Bucket {
  count: number;
  resetAt: number;
}

@Injectable()
export class AbuseLimitInterceptor implements NestInterceptor {
  private readonly buckets = new Map<string, Bucket>();

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();
    const request = context.switchToHttp().getRequest<{
      method: string;
      path?: string;
      url?: string;
      ip?: string;
      user?: { id?: string };
      body?: { phone?: string };
    }>();
    const path = (request.path || request.url || '').split('?')[0];
    const rule = this.ruleFor(request.method, path);
    if (!rule) return next.handle();
    const actor = request.user?.id || request.body?.phone || request.ip || 'anonymous';
    const key = `${rule.name}:${actor}`;
    if (this.limited(key, rule.limit, rule.windowMs)) {
      throw new HttpException('操作太頻繁，請稍後再試', HttpStatus.TOO_MANY_REQUESTS);
    }
    return next.handle();
  }

  private ruleFor(method: string, path: string): { name: string; limit: number; windowMs: number } | null {
    if (method === 'POST' && path.endsWith('/auth/send-otp')) return { name: 'otp-send', limit: 5, windowMs: 10 * 60_000 };
    if (method === 'POST' && path.endsWith('/auth/verify-otp')) return { name: 'otp-verify', limit: 10, windowMs: 10 * 60_000 };
    if (method === 'POST' && path.includes('/auth/oauth/')) return { name: 'oauth', limit: 20, windowMs: 10 * 60_000 };
    if (method === 'POST' && path.endsWith('/upload/image')) return { name: 'upload', limit: 30, windowMs: 10 * 60_000 };
    if (method === 'POST' && path.endsWith('/items')) return { name: 'item-create', limit: 20, windowMs: 60 * 60_000 };
    if (method === 'POST' && /\/chats\/[^/]+\/messages$/.test(path)) return { name: 'chat-send', limit: 60, windowMs: 60_000 };
    if (method === 'POST' && path.endsWith('/reports')) return { name: 'report', limit: 20, windowMs: 60 * 60_000 };
    if (method === 'GET' && path.includes('/qr/scan/')) return { name: 'qr-scan', limit: 60, windowMs: 10 * 60_000 };
    return null;
  }

  private limited(key: string, limit: number, windowMs: number): boolean {
    const now = Date.now();
    const bucket = this.buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      this.buckets.set(key, { count: 1, resetAt: now + windowMs });
      return false;
    }
    bucket.count += 1;
    return bucket.count > limit;
  }
}
