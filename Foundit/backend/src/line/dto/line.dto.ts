import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { CleanText } from '../../common/text-safety';

export class FinderNoticeDto {
  @ApiProperty({ example: 'K7M2P9' })
  @IsString()
  @MaxLength(200)
  code: string;

  @ApiProperty({ example: '我在圖書館二樓撿到你的背包，放在櫃台。' })
  // 留言與聯絡方式原樣轉給物主：先清掉看不見的字元與雙向控制字元，避免偽裝內容。
  @CleanText(true)
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  message: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(100)
  contact?: string;
}
