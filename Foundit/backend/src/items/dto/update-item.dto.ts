import {
  IsArray, IsBoolean, IsInt, IsNumber, IsOptional, IsString, Max, MaxLength, Min, ArrayMaxSize,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { CleanText } from '../../common/text-safety';

/** 使用者可改的欄位。主鍵、擁有人與狀態不在這裡。 */
export class UpdateItemDto {
  @ApiPropertyOptional()
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(100)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(50)
  category?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @CleanText(true)
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(30)
  color?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  images?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(200)
  locationName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(946_684_800_000)
  @Max(4_102_444_800_000)
  lostAt?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  reward?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasReward?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @CleanText()
  @IsString()
  @MaxLength(200)
  storageLocation?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  handedToPolice?: boolean;
}
