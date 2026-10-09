import { IsIn, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { MessageType } from '../../common/entities/message.entity';
import { CleanText } from '../../common/text-safety';

const CLIENT_TYPES = [MessageType.TEXT, MessageType.IMAGE, MessageType.LOCATION];

export class SendMessageDto {
  @ApiProperty({ example: '您好，這是我的鑰匙嗎？' })
  @CleanText(true)
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  content: string;

  @ApiProperty({ enum: CLIENT_TYPES, default: MessageType.TEXT })
  @Transform(({ value }) => {
    if (value == null || value === '') return MessageType.TEXT;
    return String(value).trim().toUpperCase();
  })
  @IsOptional()
  @IsIn(CLIENT_TYPES)
  type?: MessageType = MessageType.TEXT;

  @ApiProperty({ required: false, description: '客戶端冪等鍵，重送時沿用同一值' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(/^[A-Za-z0-9_-]+$/)
  client_message_id?: string;
}
