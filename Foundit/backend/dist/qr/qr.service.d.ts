import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';
import { GenerateQrDto } from './dto/generate-qr.dto';
export declare class QrService {
    private readonly qrRepo;
    private readonly config;
    constructor(qrRepo: Repository<QrItem>, config: ConfigService);
    generate(dto: GenerateQrDto, user: User): Promise<QrItem>;
    findAllByUser(userId: string): Promise<QrItem[]>;
    remove(id: string, user: User): Promise<void>;
    scanByCode(code: string): Promise<{
        qrItem: QrItem;
        owner: User;
    }>;
}
