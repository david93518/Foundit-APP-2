import {
  BadRequestException, Controller, Get, NotFoundException, Param, Post, Query, Res, UploadedFile, UseGuards, UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { join } from 'path';
import { mkdir, readdir, stat, writeFile } from 'fs/promises';
import sharp from 'sharp';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';
import { isOwnUploadName, newUploadName, publicBaseUrl, uploadSecret } from '../common/media-url';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Message, MessageType } from '../common/entities/message.entity';
import type { Response } from 'express';
import { PRIVATE_DIRECTORY, PRIVATE_MEDIA_PATH, SAFE_IMAGE_NAME } from './private-media';

const MAX_PIXELS = 16_000_000;
const ALLOWED = new Set(['jpeg', 'png', 'webp', 'gif', 'heif']);

// 解碼器不快取、一次只處理一張，惡意大圖不能一次吃光記憶體。
sharp.cache(false);
sharp.concurrency(1);

/**
 * 先看檔頭再交給 libvips：只有 JPEG／PNG／WebP／GIF／HEIC 的檔頭能進解碼器，
 * SVG、PDF、TIFF 等其他格式的解析器完全不會被觸發，縮小可被攻擊的範圍。
 */
export function hasAllowedSignature(buffer: Buffer): boolean {
  if (buffer.length < 12) return false;
  const ascii = (start: number, end: number) => buffer.toString('latin1', start, end);
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return true;
  if (buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return true;
  if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') return true;
  if (ascii(0, 6) === 'GIF87a' || ascii(0, 6) === 'GIF89a') return true;
  if (ascii(4, 8) === 'ftyp') {
    return ['heic', 'heix', 'heim', 'heis', 'hevc', 'hevx', 'mif1', 'msf1'].includes(ascii(8, 12));
  }
  return false;
}

@ApiTags('檔案上傳')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  constructor(
    private readonly config: ConfigService,
    @InjectRepository(Message) private readonly messages: Repository<Message>,
  ) {}

  @Get('chat-images/:name')
  async chatImage(@Param('name') name: string, @CurrentUser() user: User, @Res() response: Response) {
    if (!SAFE_IMAGE_NAME.test(name)) throw new NotFoundException();
    const base = publicBaseUrl(this.config);
    if (!base) throw new NotFoundException();
    const own = isOwnUploadName(name, user.id, uploadSecret(this.config));
    if (!own) {
      const count = await this.messages.createQueryBuilder('m')
        .innerJoin('chat_participants', 'p', 'p.chat_id = m.chat_id AND p.user_id = :uid', { uid: user.id })
        .where('m.type = :type AND m.content = :url', { type: MessageType.IMAGE, url: `${base}${PRIVATE_MEDIA_PATH}${name}` })
        .getCount();
      if (count === 0) throw new NotFoundException();
    }
    const file = join(process.cwd(), 'uploads', PRIVATE_DIRECTORY, name);
    if (!await stat(file).then(info => info.isFile()).catch(() => false)) throw new NotFoundException();
    response.set('Cache-Control', 'private, no-store').vary('Authorization');
    response.type('image/jpeg').sendFile(file, { dotfiles: 'allow' });
  }

  @Post('image')
  @RateLimit({ name: 'upload', limit: 30, windowMs: 10 * 60_000, by: 'user' })
  @ApiOperation({ summary: '上傳圖片，解碼後重新編碼並移除 EXIF' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', {
    storage: memoryStorage(),
    limits: { fileSize: 8 * 1024 * 1024, files: 1, fields: 5, parts: 6, fieldNameSize: 100, fieldSize: 1024 },
  }))
  async uploadImage(@UploadedFile() file: Express.Multer.File, @CurrentUser() user: User,
    @Query('scope') scope: string = 'public') {
    if (scope !== 'public' && scope !== 'chat') throw new BadRequestException('上傳用途不正確');
    if (!file?.buffer?.length) throw new BadRequestException('請選擇要上傳的圖片');
    if (!hasAllowedSignature(file.buffer)) {
      throw new BadRequestException('只接受 JPEG、PNG、WebP、GIF 或 HEIC 圖片');
    }
    const base = publicBaseUrl(this.config);
    if (!base) throw new BadRequestException('上傳服務尚未設定公開網址');

    const root = join(process.cwd(), 'uploads');
    const directory = scope === 'chat' ? join(root, PRIVATE_DIRECTORY) : root;
    await mkdir(directory, { recursive: true });
    const secret = uploadSecret(this.config);
    const existing = (await Promise.all([root, join(root, PRIVATE_DIRECTORY)]
      .map(dir => readdir(dir).catch(() => [] as string[])))).flat();
    const owned = existing.filter((name) => isOwnUploadName(name, user.id, secret)).length;
    if (owned >= 40) throw new BadRequestException('上傳數量已達上限');

    let output: Buffer;
    try {
      const image = sharp(file.buffer, { failOn: 'error', limitInputPixels: MAX_PIXELS, animated: false });
      const meta = await image.metadata();
      if (!meta.format || !ALLOWED.has(meta.format)) {
        throw new BadRequestException('只接受可解碼的點陣圖片');
      }
      const pixels = (meta.width ?? 0) * (meta.height ?? 0);
      if (!meta.width || !meta.height || pixels > MAX_PIXELS) {
        throw new BadRequestException('圖片尺寸超過上限');
      }
      output = await image.autoOrient().resize({
        width: 2000,
        height: 2000,
        fit: 'inside',
        withoutEnlargement: true,
      }).jpeg({ quality: 82, mozjpeg: true }).toBuffer();
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException('無法讀取這張圖片');
    }

    // 檔名不含帳號 id：網址公開後也看不出是誰上傳、無法串起同一人的照片，但伺服器仍能驗證擁有者。
    const filename = newUploadName(user.id, secret);
    await writeFile(join(directory, filename), output, { mode: 0o640 });
    return { success: true, url: `${base}${scope === 'chat' ? PRIVATE_MEDIA_PATH : '/uploads/'}${filename}` };
  }
}
