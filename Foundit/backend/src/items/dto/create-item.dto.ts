import {
  IsString, IsEnum, IsOptional, IsNumber, IsBoolean,
  IsArray, Min, Max, MaxLength,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { ItemType } from '../../common/entities/item.entity';

export class CreateItemDto {
  @ApiProperty({ enum: ItemType })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(ItemType)
  type: ItemType;

  @ApiProperty({ example: '黑色皮夾' })
  @IsString()
  @MaxLength(100)
  title: string;

  @ApiProperty({ example: '錢包/皮夾' })
  @IsString()
  category: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: '黑色' })
  @IsString()
  color: string;

  @ApiProperty({ type: [String], required: false })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  images?: string[];

  @ApiProperty({ example: 25.033 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  latitude?: number;

  @ApiProperty({ example: 121.565 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  longitude?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  locationName?: string;

  @ApiProperty({ example: 1743004800000, description: 'Unix timestamp ms' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lostAt?: number;

  @ApiProperty({ required: false, default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  reward?: number;

  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  hasReward?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  storageLocation?: string;

  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  handedToPolice?: boolean;
}
