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
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const auth_service_1 = require("./auth.service");
const send_otp_dto_1 = require("./dto/send-otp.dto");
const verify_otp_dto_1 = require("./dto/verify-otp.dto");
const oauth_dto_1 = require("./dto/oauth.dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
const user_mobile_serializer_1 = require("../users/user-mobile.serializer");
let AuthController = class AuthController {
    authService;
    constructor(authService) {
        this.authService = authService;
    }
    async sendOtp(dto) {
        await this.authService.sendOtp(dto);
        return { success: true, message: '驗證碼已發送' };
    }
    async verifyOtp(dto) {
        const { token, user } = await this.authService.verifyOtp(dto);
        return { success: true, token, user: (0, user_mobile_serializer_1.toMobileUser)(user) };
    }
    async oauthLogin(provider, dto) {
        const { token, user } = await this.authService.oauthLogin(provider, dto);
        return { success: true, token, user: (0, user_mobile_serializer_1.toMobileUser)(user) };
    }
    async updateFcmToken(req, fcmToken) {
        await this.authService.updateFcmToken(req.user.id, fcmToken);
        return { success: true };
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('send-otp'),
    (0, swagger_1.ApiOperation)({ summary: '發送手機 OTP 驗證碼' }),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [send_otp_dto_1.SendOtpDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "sendOtp", null);
__decorate([
    (0, common_1.Post)('verify-otp'),
    (0, swagger_1.ApiOperation)({ summary: '驗證 OTP 並登入/註冊' }),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [verify_otp_dto_1.VerifyOtpDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "verifyOtp", null);
__decorate([
    (0, common_1.Post)('oauth/:provider'),
    (0, swagger_1.ApiOperation)({ summary: '第三方 OAuth 登入 (Google / LINE)' }),
    __param(0, (0, common_1.Param)('provider')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, oauth_dto_1.OAuthDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "oauthLogin", null);
__decorate([
    (0, common_1.Patch)('fcm-token'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    (0, swagger_1.ApiOperation)({ summary: '更新 FCM 推播 Token' }),
    __param(0, (0, common_1.Request)()),
    __param(1, (0, common_1.Body)('fcm_token')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "updateFcmToken", null);
exports.AuthController = AuthController = __decorate([
    (0, swagger_1.ApiTags)('認證'),
    (0, common_1.Controller)('auth'),
    __metadata("design:paramtypes", [auth_service_1.AuthService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map