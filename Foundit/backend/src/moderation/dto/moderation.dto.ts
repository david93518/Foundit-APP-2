import {
  IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CleanText } from '../../common/text-safety';

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
  @CleanText(true)
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
  @CleanText(true)
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
  @CleanText(true)
  @IsString()
  @MinLength(2)
  @MaxLength(1000)
  reason: string;
}

export class ItemActionDto extends SuspendUserDto {}

/** 管理端清單共用的查詢參數；全域 ValidationPipe 會拒絕未列出的欄位。 */
export class AdminListQueryDto {
  @ApiPropertyOptional({ description: '關鍵字（名稱／email／手機，或物品標題／描述／地點）' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @ApiPropertyOptional({ description: '使用者：active／suspended／deleted；物品：active／resolved／closed' })
  @IsOptional()
  @IsString()
  @IsIn(['active', 'suspended', 'deleted', 'resolved', 'closed', 'ACTIVE', 'SUSPENDED', 'DELETED', 'RESOLVED', 'CLOSED'])
  status?: string;

  @ApiPropertyOptional({ enum: ['true', 'false'], description: '物品專用：true 只看已隱藏、false 只看未隱藏' })
  @IsOptional()
  @IsIn(['true', 'false'])
  hidden?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  page_size?: number = 20;
}
