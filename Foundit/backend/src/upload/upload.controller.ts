import {
  Controller, Post, UseInterceptors, UploadedFile,
  BadRequestException, UseGuards, Req,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@ApiTags('檔案上傳')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  constructor(private readonly config: ConfigService) {}

  @Post('image')
  @ApiOperation({ summary: '上傳圖片（回傳 URL）' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: join(process.cwd(), 'uploads'),
        filename: (_req, file, cb) => {
          cb(null, `${uuidv4()}${extname(file.originalname)}`);
        },
      }),
      limits: { fileSize: 10 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('image/')) {
          return cb(new BadRequestException('只允許上傳圖片'), false);
        }
        cb(null, true);
      },
    }),
  )
  async uploadImage(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request,
  ) {
    if (!file) throw new BadRequestException('請選擇要上傳的圖片');

    // 優先用 env，否則用 request 的 host（讓實機/模擬器都能正確取回）
    const envBase = this.config.get<string>('APP_BASE_URL');
    const protocol = (req.headers['x-forwarded-proto'] as string) || req.protocol;
    const host = req.headers.host;
    const baseUrl = envBase && envBase.length > 0 ? envBase : `${protocol}://${host}`;

    return {
      success: true,
      url: `${baseUrl}/uploads/${file.filename}`,
    };
  }
}
