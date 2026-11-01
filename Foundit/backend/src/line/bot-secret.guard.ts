import { CanActivate, ExecutionContext, Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'crypto';

/** LINE webhook（Supabase Edge Function）呼叫發連結端點時帶的共用密鑰。未設定時整個端點關閉。 */
@Injectable()
export class BotSecretGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const secret = this.config.get<string>('LINE_BOT_SECRET');
    if (!secret) throw new ServiceUnavailableException('LINE 服務尚未設定');
    const header = context.switchToHttp().getRequest<{ headers: Record<string, string | string[] | undefined> }>()
      .headers['x-bot-secret'];
    const given = Buffer.from(Array.isArray(header) ? header[0] : (header ?? ''));
    const expected = Buffer.from(secret);
    if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
      throw new UnauthorizedException('密鑰不正確');
    }
    return true;
  }
}
