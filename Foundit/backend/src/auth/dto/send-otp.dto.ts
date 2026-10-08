import { IsString, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { TW_MOBILE } from '../../common/phone';

export class SendOtpDto {
  @ApiProperty({ example: '0912345678', description: '台灣手機號碼（09XXXXXXXX 或 +8869XXXXXXXX）' })
  @IsString()
  @Matches(TW_MOBILE, { message: '請輸入有效的台灣手機號碼，例如 0912345678' })
  phone: string;
}
