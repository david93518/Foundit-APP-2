import { BadRequestException, Injectable, Logger, Optional, UnauthorizedException } from '@nestjs/common';
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
import { verifyInvitedCredentials } from './invited-credentials';
import { InvitedLoginDto } from './dto/invited-login.dto';
import { AdminAction } from '../common/entities/admin-action.entity';
import { cleanText, findSensitiveData, isReservedName } from '../common/text-safety';
import { isGoogleAvatar } from '../common/media-url';

/** Google 顯示名稱常是真名，也可能被設成「FOUND !T 客服」；不合適時改用預設暱稱。 */
function displayNameFromGoogle(name: string): string {
  const cleaned = cleanText(name).slice(0, 50);
  if (!cleaned || isReservedName(cleaned) || findSensitiveData(cleaned)) return 'Google 用戶';
  return cleaned;
}

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(UserPoints) private readonly pointsRepo: Repository<UserPoints>,
    private readonly otpService: OtpService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly chatsGateway: ChatsGateway,
    @Optional() @InjectRepository(AdminAction) private readonly actions?: Repository<AdminAction>,
  ) {}

  private readonly logger = new Logger(AuthService.name);

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
    user = await this.syncAdminRole(user, null);
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

    const picture = isGoogleAvatar(identity.picture) ? identity.picture : '';
    if (user) {
      user.googleSub = sub;
      if (!user.name) user.name = displayNameFromGoogle(identity.name);
      if (!user.avatarUrl) user.avatarUrl = picture;
      user.email = identity.email.slice(0, 120);
      user.isVerified = true;
      user = await this.userRepo.save(user);
      user = await this.syncAdminRole(user, identity.email);
      return { token: this.sign(user), user };
    }

    user = this.userRepo.create({
      phone: `g:${sub}`.slice(0, 100),
      googleSub: sub,
      name: displayNameFromGoogle(identity.name),
      avatarUrl: picture,
      email: identity.email.slice(0, 120),
      isVerified: true,
      role: 'user',
      status: 'active',
      tokenVersion: 0,
    });
    user = await this.userRepo.save(user);
    await this.initPoints(user.id);
    user = await this.syncAdminRole(user, identity.email);
    return { token: this.sign(user), user };
  }

  async logout(user: User): Promise<void> {
    await this.revoke(user.id);
  }

  async invitedLogin(dto: InvitedLoginDto): Promise<{ token: string; user: User }> {
    const id = await verifyInvitedCredentials(this.config, dto.username, dto.password);
    if (!id) throw new UnauthorizedException('帳號或密碼不正確，或邀請已失效');
    const user = await this.userRepo.findOne({ where: { id } });
    if (!user || user.status !== 'active' || user.role !== 'user' || user.googleSub ||
        user.phone !== `invited:${dto.username}`) {
      throw new UnauthorizedException('帳號或密碼不正確，或邀請已失效');
    }
    // No auto-registration, account linking, or admin promotion on this path.
    return { token: this.sign(user), user };
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
   * email 只採信這次登入由 Google 驗簽過的 verifiedEmail；users.email 不能拿來比對。
   * Roles are provisioned by a separate DB operator, never by the API credential.
   * An optional allow-list can further deny administrator login; it cannot grant a role.
   */
  private async syncAdminRole(user: User, verifiedEmail: string | null): Promise<User> {
    const phones = (this.config.get<string>('ADMIN_PHONES') ?? '')
      .split(',')
      .map((item) => normalizeTaiwanMobile(item))
      .filter((item) => item.startsWith('09'));
    const emails = (this.config.get<string>('ADMIN_EMAILS') ?? '')
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .filter(Boolean);
    const email = (verifiedEmail ?? '').trim().toLowerCase();
    const listed = (verifiedEmail == null && phones.includes(user.phone)) ||
      (email !== '' && emails.includes(email));
    const managed = phones.length > 0 || emails.length > 0;
    if (user.role === 'admin' && managed && !listed) {
      throw new UnauthorizedException('管理員資格需由管理者重新確認');
    }
    return user;
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
