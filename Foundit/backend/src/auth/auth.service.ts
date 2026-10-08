import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { OtpService } from './otp.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { OAuthDto } from './dto/oauth.dto';
import { GoogleIdentity, verifyGoogleIdToken } from './google-id-token';
import { normalizeTaiwanMobile } from '../common/phone';
import { ChatsGateway } from '../chats/chats.gateway';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(UserPoints) private readonly pointsRepo: Repository<UserPoints>,
    private readonly otpService: OtpService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly chatsGateway: ChatsGateway,
  ) {}

  async sendOtp(dto: SendOtpDto): Promise<void> {
    await this.otpService.send(normalizeTaiwanMobile(dto.phone));
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<{ token: string; user: User }> {
    const phone = normalizeTaiwanMobile(dto.phone);
    const ok = this.otpService.verify(phone, dto.otp);
    if (!ok) throw new BadRequestException('驗證碼錯誤或已過期');

    let user = await this.userRepo.findOne({ where: { phone } });
    if (!user) {
      user = this.userRepo.create({
        phone,
        name: `用戶${phone.slice(-4)}`,
        isVerified: true,
        role: 'user',
        status: 'active',
        tokenVersion: 0,
      });
      user = await this.userRepo.save(user);
      await this.initPoints(user.id);
    } else if (user.status === 'deleted') {
      throw new UnauthorizedException('這個帳號已刪除');
    } else if (user.status === 'suspended') {
      throw new UnauthorizedException('這個帳號已停用');
    } else {
      user.isVerified = true;
      user = await this.userRepo.save(user);
    }
    user = await this.promoteAdmin(user);
    return { token: this.sign(user), user };
  }

  async oauthLogin(provider: string, dto: OAuthDto): Promise<{ token: string; user: User }> {
    const name = provider.toLowerCase().trim();
    if (name !== 'google') {
      throw new BadRequestException('此登入方式尚未開放');
    }
    const audience = this.config.get<string>('GOOGLE_WEB_CLIENT_ID')?.trim();
    if (!audience) {
      throw new BadRequestException('Google 登入尚未開放');
    }

    let identity: GoogleIdentity;
    try {
      identity = await verifyGoogleIdToken(dto.token, audience);
    } catch {
      throw new UnauthorizedException('Google 身分驗證失敗');
    }

    const { sub } = identity;
    let user =
      (await this.userRepo.findOne({ where: { googleSub: sub } })) ||
      (await this.userRepo.findOne({ where: { phone: `google_${sub}` } }));

    if (user?.status === 'deleted' || user?.status === 'suspended') {
      throw new UnauthorizedException('這個帳號無法登入');
    }

    if (user) {
      user.googleSub = sub;
      if (!user.name) user.name = identity.name.slice(0, 50) || 'Google 用戶';
      if (!user.avatarUrl) user.avatarUrl = identity.picture;
      user.email = identity.email.slice(0, 120);
      user.isVerified = true;
      user = await this.userRepo.save(user);
      user = await this.promoteAdmin(user);
      return { token: this.sign(user), user };
    }

    user = this.userRepo.create({
      phone: `g:${sub}`.slice(0, 100),
      googleSub: sub,
      name: identity.name.slice(0, 50) || 'Google 用戶',
      avatarUrl: identity.picture,
      email: identity.email.slice(0, 120),
      isVerified: true,
      role: 'user',
      status: 'active',
      tokenVersion: 0,
    });
    user = await this.userRepo.save(user);
    await this.initPoints(user.id);
    user = await this.promoteAdmin(user);
    return { token: this.sign(user), user };
  }

  async logout(user: User): Promise<void> {
    await this.revoke(user.id);
  }

  async revoke(userId: string): Promise<void> {
    await this.userRepo.increment({ id: userId }, 'tokenVersion', 1);
    await this.userRepo.update(userId, { fcmToken: null });
    this.chatsGateway.disconnectUser(userId);
  }

  /** 一個裝置 token 只屬於最後登入的帳號，換帳號後前一位的訊息不會再推到這支手機。 */
  async updateFcmToken(userId: string, fcmToken: string): Promise<void> {
    const token = fcmToken.trim() || null;
    if (token) {
      await this.userRepo.update({ fcmToken: token, id: Not(userId) }, { fcmToken: null });
    }
    await this.userRepo.update(userId, { fcmToken: token });
  }

  /**
   * 管理員名單來自環境變數：ADMIN_PHONES（手機登入）與 ADMIN_EMAILS（Google 登入）。
   * 只在登入時提升，不會自動降級；要撤銷請直接改資料庫的 role。
   */
  private async promoteAdmin(user: User): Promise<User> {
    if (user.role === 'admin') return user;
    const phones = (this.config.get<string>('ADMIN_PHONES') ?? '')
      .split(',')
      .map((item) => normalizeTaiwanMobile(item))
      .filter((item) => item.startsWith('09'));
    const emails = (this.config.get<string>('ADMIN_EMAILS') ?? '')
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .filter(Boolean);
    const email = (user.email ?? '').trim().toLowerCase();
    const listed = phones.includes(user.phone) || (email !== '' && emails.includes(email));
    if (!listed) return user;
    user.role = 'admin';
    return this.userRepo.save(user);
  }

  private sign(user: User): string {
    return this.jwtService.sign({ sub: user.id, tv: user.tokenVersion ?? 0 });
  }

  private async initPoints(userId: string): Promise<void> {
    const existing = await this.pointsRepo.findOne({ where: { userId } });
    if (!existing) {
      await this.pointsRepo.save(this.pointsRepo.create({ userId, points: 0 }));
    }
  }
}
