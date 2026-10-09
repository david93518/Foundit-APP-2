import { IsString, Matches, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/** FCM／APNs 裝置識別。空字串代表停用這支手機的推播。 */
export class FcmTokenDto {
  @ApiProperty()
  @IsString()
  @MaxLength(512)
  @Matches(/^[A-Za-z0-9:_\-.]*$/)
  fcm_token: string;
}
