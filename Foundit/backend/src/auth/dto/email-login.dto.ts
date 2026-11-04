import { IsEmail, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { PASSWORD_MAX, PASSWORD_MIN } from '../password';

export class EmailLoginDto {
  @ApiProperty({ example: 'someone@example.com' })
  @IsEmail({}, { message: '請填寫正確的 Email' })
  @MaxLength(120)
  email: string;

  @ApiProperty({ example: 'a long passphrase' })
  @IsString()
  @MinLength(PASSWORD_MIN, { message: `密碼至少 ${PASSWORD_MIN} 個字` })
  @MaxLength(PASSWORD_MAX, { message: `密碼最多 ${PASSWORD_MAX} 個字` })
  password: string;
}

export class EmailRegisterDto extends EmailLoginDto {
  @ApiProperty({ required: false, example: '小明' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;
}
