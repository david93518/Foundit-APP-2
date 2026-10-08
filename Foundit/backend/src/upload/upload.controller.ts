import {
  BadRequestException, Controller, Post, UploadedFile, UseGuards, UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { join } from 'path';
import { mkdir, readdir, writeFile } from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';
import sharp from 'sharp';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';

const MAX_PIXELS = 16_000_000;
const ALLOWED = new Set(['jpeg', 'png', 'webp', 'gif', 'heif']);

@ApiTags('檔案上傳')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  constructor(private readonly config: ConfigService) {}

  @Post('image')
  @ApiOperation({ summary: '上傳圖片，解碼後重新編碼並移除 EXIF' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', {
    storage: memoryStorage(),
    limits: { fileSize: 8 * 1024 * 1024 },
  }))
  async uploadImage(@UploadedFile() file: Express.Multer.File, @CurrentUser() user: User) {
    if (!file?.buffer?.length) throw new BadRequestException('請選擇要上傳的圖片');
    if (/svg|html|xml/i.test(file.mimetype) || /\.(svg|html?|xml)$/i.test(file.originalname ?? '')) {
      throw new BadRequestException('不接受這個檔案格式');
    }

    const directory = join(process.cwd(), 'uploads');
    await mkdir(directory, { recursive: true });
    const existing = await readdir(directory).catch(() => [] as string[]);
    const owned = existing.filter((name) => name.startsWith(`${user.id}_`)).length;
    if (owned >= 40) throw new BadRequestException('上傳數量已達上限');

    let output: Buffer;
    try {
      const image = sharp(file.buffer, { failOn: 'error', limitInputPixels: MAX_PIXELS, animated: false });
      const meta = await image.metadata();
      if (!meta.format || !ALLOWED.has(meta.format) || meta.format === 'svg') {
        throw new BadRequestException('只接受可解碼的點陣圖片');
      }
      const pixels = (meta.width ?? 0) * (meta.height ?? 0);
      if (!meta.width || !meta.height || pixels > MAX_PIXELS) {
        throw new BadRequestException('圖片尺寸超過上限');
      }
      output = await image.rotate().resize({
        width: 2000,
        height: 2000,
        fit: 'inside',
        withoutEnlargement: true,
      }).jpeg({ quality: 82, mozjpeg: true }).toBuffer();
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException('無法讀取這張圖片');
    }

    const filename = `${user.id}_${uuidv4()}.jpg`;
    await writeFile(join(directory, filename), output);
    return { success: true, url: `${this.publicBase()}/uploads/${filename}` };
  }

  private publicBase(): string {
    const configured = this.config.get<string>('APP_BASE_URL')?.trim().replace(/\/$/, '');
    if (configured) return configured;
    if (this.config.get<string>('NODE_ENV') === 'production') {
      throw new BadRequestException('上傳服務尚未設定公開網址');
    }
    return `http://127.0.0.1:${this.config.get<string>('PORT') ?? '3000'}`;
  }
}
