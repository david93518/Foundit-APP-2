import { IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength, ValidateIf } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateQrBatchDto {
  @ApiProperty({ example: '成大圖書館 2026-11' })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  label: string;

  @ApiProperty({ required: false, example: '總圖一樓' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  place?: string;

  @ApiProperty({ example: 100, minimum: 1, maximum: 500 })
  @IsInt()
  @Min(1)
  @Max(500)
  count: number;
}

export class DisableQrDto {
  @ApiProperty({ required: false, description: '單張貼紙編號' })
  @ValidateIf((o: DisableQrDto) => !o.batch_id)
  @IsString()
  @MaxLength(200)
  code?: string;

  @ApiProperty({ required: false, description: '整批停用' })
  @ValidateIf((o: DisableQrDto) => !o.code)
  @IsUUID()
  batch_id?: string;
}
