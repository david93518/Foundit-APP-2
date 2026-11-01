import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class FinderNoticeDto {
  @ApiProperty({ example: 'K7M2P9' })
  @IsString()
  @MaxLength(200)
  code: string;

  @ApiProperty({ example: '我在圖書館二樓撿到你的背包，放在櫃台。' })
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  message: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  contact?: string;
}
