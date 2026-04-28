import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
export declare class UploadController {
    private readonly config;
    constructor(config: ConfigService);
    uploadImage(file: Express.Multer.File, req: Request): Promise<{
        success: boolean;
        url: string;
    }>;
}
