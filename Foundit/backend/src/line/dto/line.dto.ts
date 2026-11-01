import { IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateLineLinkDto {
  @ApiProperty({ example: 'U0123456789abcdef0123456789abcdef', description: 'LINE userId' })
  @Matches(/^U[0-9a-f]{32}$/)
  line_user: string;

  @ApiProperty({ required: false, minimum: 5, maximum: 1440, description: '連結有效分鐘數' })
  @IsOptional()
  @IsInt()
  @Min(5)
  @Max(1440)
  ttl_minutes?: number;
}

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
