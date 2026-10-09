import {
  ArrayMaxSize, Equals, IsArray, IsBoolean, IsInt, IsEnum, IsNumber, IsOptional, IsString,
  Max, MaxLength, Min, MinLength,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { ItemType } from '../../common/entities/item.entity';
import { CleanText } from '../../common/text-safety';

export class CreateItemDto {
  @ApiProperty({ enum: ItemType })
  @Transform(({ value }) => (typeof value === 'string' ? value.toUpperCase() : value))
  @IsEnum(ItemType)
  type: ItemType;

  @ApiProperty({ example: '黑色皮夾' })
  @CleanText()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  title: string;

  @ApiProperty({ example: '錢包/皮夾' })
  @CleanText()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  category: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @CleanText(true)
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiProperty({ example: '黑色' })
  @CleanText()
  @IsString()
  @MaxLength(30)
  color: string;

  @ApiProperty({ type: [String], required: false })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  images?: string[];

  @ApiProperty({ example: 25.033 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiProperty({ example: 121.565 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(200)
  locationName?: string;

  @ApiProperty({ example: 1743004800000, description: 'Unix timestamp ms' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(946_684_800_000)
  @Max(4_102_444_800_000)
  lostAt?: number;

  @ApiProperty({ required: false, default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  reward?: number;

  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  hasReward?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(200)
  storageLocation?: string;

  @ApiProperty({ required: false, default: false })
  @IsOptional()
  @IsBoolean()
  handedToPolice?: boolean;

  @ApiProperty({ description: '必須明確同意目前版本的刊登規範' })
  @Equals(true)
  termsAccepted: boolean;

  @ApiProperty({ example: '2026-10-04' })
  @IsString()
  @MinLength(1)
  @MaxLength(32)
  termsVersion: string;
}
