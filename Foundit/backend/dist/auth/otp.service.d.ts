import { ConfigService } from '@nestjs/config';
export declare class OtpService {
    private readonly config;
    private readonly logger;
    private readonly store;
    private readonly MAX_ATTEMPTS;
    constructor(config: ConfigService);
    send(phone: string): Promise<void>;
    verify(phone: string, code: string): boolean;
    private generateCode;
    private sendViaSms;
}
