import { IsString, IsEnum, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { MessageType } from '../../common/entities/message.entity';

export class SendMessageDto {
  @ApiProperty({ example: '您好，這是我的鑰匙嗎？' })
  @IsString()
  @MaxLength(500)
  content: string;

  @ApiProperty({ enum: MessageType, default: MessageType.TEXT })
  @IsOptional()
  @IsEnum(MessageType)
  type?: MessageType = MessageType.TEXT;
}
