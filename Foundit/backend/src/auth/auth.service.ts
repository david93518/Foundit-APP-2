import {
  Injectable,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';
import { createHash } from 'crypto';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { OtpService } from './otp.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { OAuthDto } from './dto/oauth.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(UserPoints) private readonly pointsRepo: Repository<UserPoints>,
    private readonly otpService: OtpService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {}

  async sendOtp(dto: SendOtpDto): Promise<void> {
    const phone = this.normalizePhone(dto.phone);
    await this.otpService.send(phone);
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<{ token: string; user: User }> {
    const phone = this.normalizePhone(dto.phone);
    const ok = this.otpService.verify(phone, dto.otp);
    if (!ok) throw new BadRequestException('驗證碼錯誤或已過期');

    let user = await this.userRepo.findOne({ where: { phone } });
    if (!user) {
      user = this.userRepo.create({ phone, name: `用戶${phone.slice(-4)}`, isVerified: true });
      user = await this.userRepo.save(user);
      await this.initPoints(user.id);
    } else {
      user.isVerified = true;
      user = await this.userRepo.save(user);
    }

    return { token: this.sign(user), user };
  }

  async oauthLogin(provider: string, dto: OAuthDto): Promise<{ token: string; user: User }> {
    const p = provider.toLowerCase().trim();
    if (p === 'google') {
      return this.loginWithGoogle(dto);
    }

    const externalKey = this.resolveOAuthExternalKeyNonGoogle(p, dto.token);
    const fakePhone = `${p.slice(0, 12)}_${externalKey}`.slice(0, 100);

    let user = await this.userRepo.findOne({ where: { phone: fakePhone } });
    if (!user) {
      user = this.userRepo.create({
        phone: fakePhone,
        name: dto.name || `${provider} 用戶`,
        avatarUrl: dto.avatarUrl || '',
        isVerified: true,
      });
      user = await this.userRepo.save(user);
      await this.initPoints(user.id);
    }
    return { token: this.sign(user), user };
  }

  /**
   * Google 專用：以 id_token 的 sub ＋ 資料庫 google_sub 欄位綁定帳號，不再只靠 phone 字串。
   * 舊版用 JWT 前 8 字或僅 phone 比對時，曾讓所有人變成同一 user，導致無法與他人開聊天室。
   */
  private async loginWithGoogle(dto: OAuthDto): Promise<{ token: string; user: User }> {
    const sub = await this.resolveGoogleIdTokenSubject(dto.token);

    let user =
      (await this.userRepo.findOne({ where: { googleSub: sub } })) ||
      (await this.userRepo.findOne({ where: { phone: `google_${sub}` } }));

    if (user) {
      user.googleSub = sub;
      if (dto.name?.trim()) user.name = dto.name.trim();
      if (dto.avatarUrl?.trim()) user.avatarUrl = dto.avatarUrl.trim();
      user.isVerified = true;
      user = await this.userRepo.save(user);
      return { token: this.sign(user), user };
    }

    const phone = `g:${sub}`.slice(0, 100);
    user = this.userRepo.create({
      phone,
      googleSub: sub,
      name: dto.name?.trim() || 'Google 用戶',
      avatarUrl: dto.avatarUrl?.trim() || '',
      isVerified: true,
    });
    user = await this.userRepo.save(user);
    await this.initPoints(user.id);
    return { token: this.sign(user), user };
  }

  /** 非 Google 的 OAuth（預留）：JWT sub 或 token hash */
  private resolveOAuthExternalKeyNonGoogle(provider: string, token: string): string {
    const jwtSub = this.decodeJwtPayloadSub(token);
    if (jwtSub) return jwtSub;
    return createHash('sha256').update(token, 'utf8').digest('hex').slice(0, 32);
  }

  private async resolveGoogleIdTokenSubject(idToken: string): Promise<string> {
    const audience = this.config.get<string>('GOOGLE_WEB_CLIENT_ID')?.trim();
    if (audience) {
      try {
        const client = new OAuth2Client(audience);
        const ticket = await client.verifyIdToken({ idToken, audience });
        const sub = ticket.getPayload()?.sub;
        if (sub) return sub;
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        this.logger.warn(
          `Google verifyIdToken 失敗，改解碼 JWT 取 sub（請確認 .env GOOGLE_WEB_CLIENT_ID 與 App 網頁 Client ID 一致）: ${msg}`,
        );
      }
    }

    const sub = this.decodeJwtPayloadSub(idToken);
    if (sub) {
      if (!audience) {
        this.logger.warn('GOOGLE_WEB_CLIENT_ID 未設定：已僅解碼 id_token 取得 sub');
      }
      return sub;
    }
    throw new BadRequestException(
      '無法解析 Google id_token，請確認已傳入 id_token 且後端 GOOGLE_WEB_CLIENT_ID 正確',
    );
  }

  /** 不驗簽，僅取出 JWT payload 的 sub（僅供未設定 GOOGLE_WEB_CLIENT_ID 時區分用戶） */
  private decodeJwtPayloadSub(token: string): string | null {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    try {
      let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const pad = b64.length % 4;
      if (pad) b64 += '='.repeat(4 - pad);
      const json = Buffer.from(b64, 'base64').toString('utf8');
      const payload = JSON.parse(json) as { sub?: string };
      return typeof payload.sub === 'string' && payload.sub.length > 0 ? payload.sub : null;
    } catch {
      return null;
    }
  }

  async updateFcmToken(userId: string, fcmToken: string): Promise<void> {
    await this.userRepo.update(userId, { fcmToken });
  }

  private sign(user: User): string {
    return this.jwtService.sign({ sub: user.id, phone: user.phone });
  }

  private async initPoints(userId: string): Promise<void> {
    const existing = await this.pointsRepo.findOne({ where: { userId } });
    if (!existing) {
      await this.pointsRepo.save(this.pointsRepo.create({ userId, points: 0 }));
    }
  }

  private normalizePhone(phone: string): string {
    // 移除空白、橫線，將 +8869... 或 8869... 轉為 09...
    let p = phone.replace(/[\s\-]/g, '');
    if (p.startsWith('+886')) p = '0' + p.slice(4);
    else if (p.startsWith('886')) p = '0' + p.slice(3);
    return p;
  }
}
