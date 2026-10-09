import { IsString, IsOptional, MaxLength, MinLength } from 'class-validator';
import { CleanText } from '../../common/text-safety';
import { ApiProperty } from '@nestjs/swagger';

export class GenerateQrDto {
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

/** 編輯防丟牌：欄位與建立時相同。 */
export class UpdateQrDto extends GenerateQrDto {}
