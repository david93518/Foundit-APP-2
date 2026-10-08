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

@ApiTags('認證')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('send-otp')
  @ApiOperation({ summary: '發送手機 OTP 驗證碼' })
  async sendOtp(@Body() dto: SendOtpDto) {
    await this.authService.sendOtp(dto);
    return { success: true, message: '驗證碼已發送' };
  }

  @Post('verify-otp')
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
  @ApiOperation({ summary: '第三方 OAuth 登入 (Google / LINE)' })
  async oauthLogin(@Param('provider') provider: string, @Body() dto: OAuthDto) {
    const { token, user } = await this.authService.oauthLogin(provider, dto);
    return { success: true, token, user: toMobileUser(user) };
  }

  @Patch('fcm-token')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新 FCM 推播 Token' })
  async updateFcmToken(@CurrentUser() user: User, @Body('fcm_token') fcmToken: string) {
    if (typeof fcmToken !== 'string' || fcmToken.length > 512) {
      return { success: false, message: '推播識別無效' };
    }
    await this.authService.updateFcmToken(user.id, fcmToken);
    return { success: true };
  }
}
