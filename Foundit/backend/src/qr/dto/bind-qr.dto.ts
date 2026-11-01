import { IsString, IsOptional, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { CleanText } from '../../common/text-safety';

export class BindQrDto {
  @ApiProperty({ example: 'K7M2P9', description: '貼紙上的 6 碼編號，也可以貼上掃到的整串貼紙網址' })
  @IsString()
  @MaxLength(200)
  code: string;

  @ApiProperty({ example: '我的後背包' })
  @CleanText()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @CleanText(true)
  @IsString()
  @MaxLength(500)
  description?: string;
}

export class UpdateQrDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @CleanText()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @CleanText(true)
  @IsString()
  @MaxLength(500)
  description?: string;
}
