import { AuthService } from './auth.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { OAuthDto } from './dto/oauth.dto';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    sendOtp(dto: SendOtpDto): Promise<{
        success: boolean;
        message: string;
    }>;
    verifyOtp(dto: VerifyOtpDto): Promise<{
        success: boolean;
        token: string;
        user: Record<string, unknown>;
    }>;
    oauthLogin(provider: string, dto: OAuthDto): Promise<{
        success: boolean;
        token: string;
        user: Record<string, unknown>;
    }>;
    updateFcmToken(req: any, fcmToken: string): Promise<{
        success: boolean;
    }>;
}
