import {
  Controller, Post, Body, Param, Patch, UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { OAuthDto } from './dto/oauth.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { toMobileUser } from '../users/user-mobile.serializer';
import { InvitedLoginDto } from './dto/invited-login.dto';
import { FcmTokenDto } from './dto/fcm-token.dto';
import { RateLimit } from '../common/abuse-limit.interceptor';

@ApiTags('認證')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('invited-login')
  @RateLimit(
    { name: 'invited-login', limit: 10, windowMs: 60_000, by: 'ip' },
    { name: 'invited-login-hour', limit: 30, windowMs: 60 * 60_000, by: 'ip' },
  )
  @ApiOperation({ summary: '使用已核發的受邀帳號登入' })
  async invitedLogin(@Body() dto: InvitedLoginDto) {
    const { token, user } = await this.authService.invitedLogin(dto);
    return { success: true, token, user: toMobileUser(user) };
  }

  @Post('send-otp')
  @RateLimit({ name: 'otp-send', limit: 5, windowMs: 10 * 60_000, by: 'ip' })
  @ApiOperation({ summary: '發送手機 OTP 驗證碼' })
  async sendOtp(@Body() dto: SendOtpDto) {
    await this.authService.sendOtp(dto);
    return { success: true, message: '驗證碼已發送' };
  }

  @Post('verify-otp')
  @RateLimit({ name: 'otp-verify', limit: 10, windowMs: 10 * 60_000, by: 'ip' })
  @ApiOperation({ summary: '驗證 OTP 並登入/註冊' })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    const { token, user } = await this.authService.verifyOtp(dto);
    return { success: true, token, user: toMobileUser(user) };
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '登出並撤銷目前帳號的既有 token' })
  async logout(@CurrentUser() user: User) {
    await this.authService.logout(user);
    return { success: true };
  }

  @Post('oauth/:provider')
  @RateLimit({ name: 'oauth', limit: 20, windowMs: 10 * 60_000, by: 'ip' })
  @ApiOperation({ summary: '第三方 OAuth 登入 (Google / LINE)' })
  async oauthLogin(@Param('provider') provider: string, @Body() dto: OAuthDto) {
    const { token, user } = await this.authService.oauthLogin(provider, dto);
    return { success: true, token, user: toMobileUser(user) };
  }

  @Patch('fcm-token')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'fcm-token', limit: 20, windowMs: 10 * 60_000, by: 'user' })
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新 FCM 推播 Token' })
  async updateFcmToken(@CurrentUser() user: User, @Body() dto: FcmTokenDto) {
    await this.authService.updateFcmToken(user.id, dto.fcm_token);
    return { success: true };
  }
}
