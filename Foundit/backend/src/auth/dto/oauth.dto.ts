import { IsString, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class OAuthDto {
  @ApiProperty({ example: 'google_id_token_here' })
  @IsString()
  @MaxLength(8192)
  token: string;

  @ApiProperty({ example: 'google' })
  @IsString()
  @MaxLength(20)
  provider: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;
}
