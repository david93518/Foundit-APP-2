import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateReportDto {
  @ApiProperty({ enum: ['item', 'user', 'message'] })
  @IsIn(['item', 'user', 'message'])
  targetType: 'item' | 'user' | 'message';

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  targetId: string;

  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(1000)
  reason: string;
}

export class ResolveReportDto {
  @ApiProperty({ enum: ['hide', 'dismiss', 'suspend'] })
  @IsIn(['hide', 'dismiss', 'suspend'])
  action: 'hide' | 'dismiss' | 'suspend';

  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(1000)
  reason: string;
}

export class BlockUserDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  userId: string;
}

export class SuspendUserDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(1000)
  reason: string;
}
