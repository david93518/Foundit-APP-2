import { QrService } from './qr.service';
import { GenerateQrDto } from './dto/generate-qr.dto';
import { User } from '../common/entities/user.entity';
export declare class QrController {
    private readonly qrService;
    constructor(qrService: QrService);
    generate(dto: GenerateQrDto, user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    findAll(user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>[];
    }>;
    remove(id: string, user: User): Promise<{
        success: boolean;
        message: string;
    }>;
    scan(code: string): Promise<{
        success: boolean;
        qr_item: Record<string, unknown>;
        owner: Record<string, unknown>;
    }>;
}
