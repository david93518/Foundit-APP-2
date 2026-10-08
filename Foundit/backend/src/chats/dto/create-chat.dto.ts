import { IsOptional, IsString, IsUUID, Matches, ValidateIf } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/** 二選一：刊登物品的 item_id，或掃到的防丟牌代碼 qr_code。 */
export class CreateChatDto {
  @ApiProperty({ example: 'item-uuid-here', required: false })
  @ValidateIf((dto: CreateChatDto) => dto.qr_code == null)
  @IsUUID()
  item_id?: string;

  @ApiProperty({ example: 'qr-code-from-sticker', required: false })
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z0-9-]{8,80}$/)
  qr_code?: string;
}
