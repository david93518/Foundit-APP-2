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
var OtpService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.OtpService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
let OtpService = OtpService_1 = class OtpService {
    config;
    logger = new common_1.Logger(OtpService_1.name);
    store = new Map();
    MAX_ATTEMPTS = 5;
    constructor(config) {
        this.config = config;
    }
    async send(phone) {
        const code = this.generateCode();
        const expiresMinutes = this.config.get('OTP_EXPIRES_MINUTES', 5);
        const expiresAt = new Date(Date.now() + expiresMinutes * 60 * 1000);
        this.store.set(phone, { code, expiresAt, attempts: 0 });
        const driver = this.config.get('OTP_DRIVER', 'console');
        if (driver === 'console') {
            this.logger.log(`[OTP] 手機 ${phone} 驗證碼：${code}（${expiresMinutes} 分鐘有效）`);
        }
        else {
            await this.sendViaSms(phone, code);
        }
    }
    verify(phone, code) {
        const record = this.store.get(phone);
        if (!record)
            return false;
        if (new Date() > record.expiresAt) {
            this.store.delete(phone);
            return false;
        }
        record.attempts++;
        if (record.attempts > this.MAX_ATTEMPTS) {
            this.store.delete(phone);
            return false;
        }
        if (record.code !== code)
            return false;
        this.store.delete(phone);
        return true;
    }
    generateCode() {
        return Math.floor(100000 + Math.random() * 900000).toString();
    }
    async sendViaSms(phone, code) {
        this.logger.warn(`SMS 未設定，OTP ${code} 無法傳送至 ${phone}`);
    }
};
exports.OtpService = OtpService;
exports.OtpService = OtpService = OtpService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], OtpService);
//# sourceMappingURL=otp.service.js.map