import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { OtpService } from './otp.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { OAuthDto } from './dto/oauth.dto';
export declare class AuthService {
    private readonly userRepo;
    private readonly pointsRepo;
    private readonly otpService;
    private readonly jwtService;
    private readonly config;
    private readonly logger;
    constructor(userRepo: Repository<User>, pointsRepo: Repository<UserPoints>, otpService: OtpService, jwtService: JwtService, config: ConfigService);
    sendOtp(dto: SendOtpDto): Promise<void>;
    verifyOtp(dto: VerifyOtpDto): Promise<{
        token: string;
        user: User;
    }>;
    oauthLogin(provider: string, dto: OAuthDto): Promise<{
        token: string;
        user: User;
    }>;
    private loginWithGoogle;
    private resolveOAuthExternalKeyNonGoogle;
    private resolveGoogleIdTokenSubject;
    private decodeJwtPayloadSub;
    updateFcmToken(userId: string, fcmToken: string): Promise<void>;
    private sign;
    private initPoints;
    private normalizePhone;
}
