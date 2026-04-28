import { IsString, Matches, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyOtpDto {
  @ApiProperty({ example: '0912345678' })
  @IsString()
  @Matches(/^(\+?886-?)?09\d{8}$/, { message: '請輸入有效的台灣手機號碼' })
  phone: string;

  @ApiProperty({ example: '123456', description: '6 位數驗證碼' })
  @IsString()
  @Length(6, 6, { message: '驗證碼必須為 6 位數' })
  otp: string;
}
