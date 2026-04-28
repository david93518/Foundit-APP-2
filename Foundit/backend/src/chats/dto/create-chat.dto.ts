import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateChatDto {
  @ApiProperty({ example: 'item-uuid-here' })
  @IsUUID()
  item_id: string;
}
