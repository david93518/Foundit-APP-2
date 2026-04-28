import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { v4 as uuidv4 } from 'uuid';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';
import { GenerateQrDto } from './dto/generate-qr.dto';

@Injectable()
export class QrService {
  constructor(
    @InjectRepository(QrItem) private readonly qrRepo: Repository<QrItem>,
    private readonly config: ConfigService,
  ) {}

  async generate(dto: GenerateQrDto, user: User): Promise<QrItem> {
    const code = uuidv4();
    const baseUrl = this.config.get<string>('APP_BASE_URL', 'http://localhost:3000');
    const qrCode = `${baseUrl}/qr/${code}`;

    const qrItem = this.qrRepo.create({
      userId: user.id,
      name: dto.name,
      description: dto.description ?? '',
      qrCode,
      qrImageUrl: '',
    });
    return this.qrRepo.save(qrItem);
  }

  async findAllByUser(userId: string): Promise<QrItem[]> {
    return this.qrRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  async remove(id: string, user: User): Promise<void> {
    const qrItem = await this.qrRepo.findOne({ where: { id } });
    if (!qrItem) throw new NotFoundException('QR 物品不存在');
    if (qrItem.userId !== user.id) throw new ForbiddenException('無權限刪除此 QR');
    await this.qrRepo.remove(qrItem);
  }

  async scanByCode(code: string): Promise<{ qrItem: QrItem; owner: User }> {
    const baseUrl = this.config.get<string>('APP_BASE_URL', 'http://localhost:3000');
    const qrCode = `${baseUrl}/qr/${code}`;
    const qrItem = await this.qrRepo.findOne({
      where: { qrCode },
      relations: ['user'],
    });
    if (!qrItem) throw new NotFoundException('QR Code 無效或已刪除');
    return { qrItem, owner: qrItem.user };
  }
}
