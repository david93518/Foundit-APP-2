import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import sharp from 'sharp';
import { ConfigService } from '@nestjs/config';
import type { Response } from 'express';
import { CampusService } from './campus.service';
import { OptionalJwtAuthGuard } from '../common/guards/optional-jwt-auth.guard';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';
import { MediaStorageService } from '../upload/media-storage.service';
import { hasAllowedSignature } from '../upload/upload.controller';
import { newUploadName, uploadSecret } from '../common/media-url';

@Controller('campus')
export class CampusController {
  constructor(
    private readonly campus: CampusService,
    private readonly media: MediaStorageService,
    private readonly config: ConfigService,
  ) {}
  /**
   * 撿到者的聊天室每 5 秒輪詢一次對話。很多人共用同一個校園 Wi-Fi（同一個對外 IP）時，
   * 一般的 120 次很快就會用完，所以這支另外計算。它要帶 256 位元的對話 token，猜不到，
   * 放寬也不會讓人猜碼；每個 IP 的總量仍受 main.ts 每分鐘 600 次的上限約束。
   * 必須宣告在 rpc/:name 之前，路由才會先比對到這裡。
   */
  @Post('rpc/sticker_thread_finder')
  @UseGuards(OptionalJwtAuthGuard)
  @RateLimit({
    name: 'campus-thread-poll',
    limit: 600,
    windowMs: 60000,
    by: 'ip',
  })
  async finderThread(
    @Body() args: Record<string, unknown>,
    @CurrentUser() user?: User,
  ) {
    return {
      success: true,
      data: await this.campus.call('sticker_thread_finder', args, user),
    };
  }
  /** 已登入的人以帳號計算額度，同一個 Wi-Fi 下的其他人不會互相拖累；未登入的人以來源 IP 計算。 */
  @Post('rpc/:name')
  @UseGuards(OptionalJwtAuthGuard)
  @RateLimit({ name: 'campus-rpc', limit: 120, windowMs: 60000, by: 'user' })
  async rpc(
    @Param('name') name: string,
    @Body() args: Record<string, unknown>,
    @CurrentUser() user?: User,
  ) {
    return { success: true, data: await this.campus.call(name, args, user) };
  }
  @Post('photos')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'staff-photo', limit: 30, windowMs: 600000, by: 'user' })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 800 * 1024, files: 1, fields: 0, parts: 1 },
    }),
  )
  async upload(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: User,
  ) {
    await this.campus.staff(user);
    if (!file?.buffer || !hasAllowedSignature(file.buffer))
      throw new BadRequestException('照片格式不正確');
    let output: Buffer;
    try {
      output = await sharp(file.buffer, {
        limitInputPixels: 16000000,
        animated: false,
      })
        .autoOrient()
        .resize({
          width: 1600,
          height: 1600,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .jpeg({ quality: 82 })
        .toBuffer();
    } catch {
      throw new BadRequestException('無法讀取這張照片');
    }
    const name = newUploadName(user.id, uploadSecret(this.config));
    await this.media.put('staff', name, output);
    return { success: true, data: name };
  }
  @Get('photos/:name')
  @UseGuards(JwtAuthGuard)
  async photo(
    @Param('name') name: string,
    @CurrentUser() user: User,
    @Res() response: Response,
  ) {
    await this.campus.staff(user);
    response
      .set('Cache-Control', 'private, no-store')
      .vary('Authorization')
      .type('image/jpeg')
      .send(await this.media.read('staff', name));
  }
}
