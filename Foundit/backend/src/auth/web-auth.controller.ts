import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { OAuthDto } from './dto/oauth.dto';
import { EmailLoginDto, EmailRegisterDto } from './dto/email-login.dto';
import { toMobileUser } from '../users/user-mobile.serializer';
import { RateLimit } from '../common/abuse-limit.interceptor';

const COOKIE = '__Secure-foundit-web';
const options = {
  httpOnly: true,
  secure: true,
  sameSite: 'lax' as const,
  path: '/api/v1/auth',
};

/** Cookie is only a session bootstrap credential. Business endpoints still require a bearer token. */
@Controller('auth')
export class WebAuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly db: DataSource,
  ) {}
  private origin(req: Request) {
    const allowed = (process.env.CORS_ORIGINS ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    if (!req.headers.origin || !allowed.includes(req.headers.origin))
      throw new ForbiddenException('不允許的網站來源');
  }
  private cookie(req: Request) {
    return (
      (req.headers.cookie ?? '')
        .split(';')
        .map((s) => s.trim())
        .find((s) => s.startsWith(COOKIE + '='))
        ?.slice(COOKIE.length + 1) ?? ''
    );
  }
  @Post('web-google')
  @RateLimit({ name: 'web-google', limit: 20, windowMs: 600000, by: 'ip' })
  async login(
    @Body() dto: OAuthDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    this.origin(req);
    return this.start(await this.auth.oauthLogin('google', dto, true), res);
  }
  /** Email＋密碼帳號，和 Google 帳號分開（見 AuthService.emailRegister）。 */
  @Post('web-email/register')
  @RateLimit({ name: 'web-email-register', limit: 10, windowMs: 3600000, by: 'ip' })
  async emailRegister(
    @Body() dto: EmailRegisterDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    this.origin(req);
    return this.start(await this.auth.emailRegister(dto), res);
  }
  @Post('web-email/login')
  @RateLimit({ name: 'web-email-login', limit: 30, windowMs: 600000, by: 'ip' })
  async emailLogin(
    @Body() dto: EmailLoginDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    this.origin(req);
    return this.start(await this.auth.emailLogin(dto), res);
  }
  /** Same for every sign-in method: register the campus member, set the session cookie, return the token. */
  private async start(session: { token: string; user: Parameters<typeof toMobileUser>[0] }, res: Response) {
    await this.db.query(
      'INSERT INTO campus.members(user_id) VALUES($1) ON CONFLICT(user_id) DO UPDATE SET last_seen=now()',
      [session.user.id],
    );
    const expiry = this.auth.tokenExpiry(session.token);
    res
      .set('Cache-Control', 'no-store')
      .cookie(COOKIE, session.token, { ...options, expires: new Date(expiry) });
    return {
      success: true,
      token: session.token,
      user: toMobileUser(session.user),
    };
  }
  @Get('web-session')
  @RateLimit({ name: 'web-session', limit: 60, windowMs: 60000, by: 'ip' })
  async session(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    this.origin(req);
    res.set('Cache-Control', 'no-store');
    const token = this.cookie(req);
    const user = await this.auth.webSession(token);
    return { success: true, token, user: toMobileUser(user) };
  }
  @Post('web-logout')
  async logout(@Req() req: Request, @Res({ passthrough: true }) res: Response) {
    this.origin(req);
    res.set('Cache-Control', 'no-store').clearCookie(COOKIE, options);
    // Clear this browser's bootstrap cookie; do not disconnect the user's phone.
    return { success: true };
  }
}
