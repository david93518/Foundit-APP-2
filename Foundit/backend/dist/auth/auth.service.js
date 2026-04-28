"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var AuthService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const config_1 = require("@nestjs/config");
const google_auth_library_1 = require("google-auth-library");
const crypto_1 = require("crypto");
const user_entity_1 = require("../common/entities/user.entity");
const user_points_entity_1 = require("../common/entities/user-points.entity");
const otp_service_1 = require("./otp.service");
let AuthService = AuthService_1 = class AuthService {
    userRepo;
    pointsRepo;
    otpService;
    jwtService;
    config;
    logger = new common_1.Logger(AuthService_1.name);
    constructor(userRepo, pointsRepo, otpService, jwtService, config) {
        this.userRepo = userRepo;
        this.pointsRepo = pointsRepo;
        this.otpService = otpService;
        this.jwtService = jwtService;
        this.config = config;
    }
    async sendOtp(dto) {
        const phone = this.normalizePhone(dto.phone);
        await this.otpService.send(phone);
    }
    async verifyOtp(dto) {
        const phone = this.normalizePhone(dto.phone);
        const ok = this.otpService.verify(phone, dto.otp);
        if (!ok)
            throw new common_1.BadRequestException('驗證碼錯誤或已過期');
        let user = await this.userRepo.findOne({ where: { phone } });
        if (!user) {
            user = this.userRepo.create({ phone, name: `用戶${phone.slice(-4)}`, isVerified: true });
            user = await this.userRepo.save(user);
            await this.initPoints(user.id);
        }
        else {
            user.isVerified = true;
            user = await this.userRepo.save(user);
        }
        return { token: this.sign(user), user };
    }
    async oauthLogin(provider, dto) {
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
    async loginWithGoogle(dto) {
        const sub = await this.resolveGoogleIdTokenSubject(dto.token);
        let user = (await this.userRepo.findOne({ where: { googleSub: sub } })) ||
            (await this.userRepo.findOne({ where: { phone: `google_${sub}` } }));
        if (user) {
            user.googleSub = sub;
            if (dto.name?.trim())
                user.name = dto.name.trim();
            if (dto.avatarUrl?.trim())
                user.avatarUrl = dto.avatarUrl.trim();
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
    resolveOAuthExternalKeyNonGoogle(provider, token) {
        const jwtSub = this.decodeJwtPayloadSub(token);
        if (jwtSub)
            return jwtSub;
        return (0, crypto_1.createHash)('sha256').update(token, 'utf8').digest('hex').slice(0, 32);
    }
    async resolveGoogleIdTokenSubject(idToken) {
        const audience = this.config.get('GOOGLE_WEB_CLIENT_ID')?.trim();
        if (audience) {
            try {
                const client = new google_auth_library_1.OAuth2Client(audience);
                const ticket = await client.verifyIdToken({ idToken, audience });
                const sub = ticket.getPayload()?.sub;
                if (sub)
                    return sub;
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : String(e);
                this.logger.warn(`Google verifyIdToken 失敗，改解碼 JWT 取 sub（請確認 .env GOOGLE_WEB_CLIENT_ID 與 App 網頁 Client ID 一致）: ${msg}`);
            }
        }
        const sub = this.decodeJwtPayloadSub(idToken);
        if (sub) {
            if (!audience) {
                this.logger.warn('GOOGLE_WEB_CLIENT_ID 未設定：已僅解碼 id_token 取得 sub');
            }
            return sub;
        }
        throw new common_1.BadRequestException('無法解析 Google id_token，請確認已傳入 id_token 且後端 GOOGLE_WEB_CLIENT_ID 正確');
    }
    decodeJwtPayloadSub(token) {
        const parts = token.split('.');
        if (parts.length !== 3)
            return null;
        try {
            let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
            const pad = b64.length % 4;
            if (pad)
                b64 += '='.repeat(4 - pad);
            const json = Buffer.from(b64, 'base64').toString('utf8');
            const payload = JSON.parse(json);
            return typeof payload.sub === 'string' && payload.sub.length > 0 ? payload.sub : null;
        }
        catch {
            return null;
        }
    }
    async updateFcmToken(userId, fcmToken) {
        await this.userRepo.update(userId, { fcmToken });
    }
    sign(user) {
        return this.jwtService.sign({ sub: user.id, phone: user.phone });
    }
    async initPoints(userId) {
        const existing = await this.pointsRepo.findOne({ where: { userId } });
        if (!existing) {
            await this.pointsRepo.save(this.pointsRepo.create({ userId, points: 0 }));
        }
    }
    normalizePhone(phone) {
        let p = phone.replace(/[\s\-]/g, '');
        if (p.startsWith('+886'))
            p = '0' + p.slice(4);
        else if (p.startsWith('886'))
            p = '0' + p.slice(3);
        return p;
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = AuthService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(1, (0, typeorm_1.InjectRepository)(user_points_entity_1.UserPoints)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        otp_service_1.OtpService,
        jwt_1.JwtService,
        config_1.ConfigService])
], AuthService);
//# sourceMappingURL=auth.service.js.map