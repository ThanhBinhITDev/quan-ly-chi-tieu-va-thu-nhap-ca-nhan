import {
  IsBoolean,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Min,
} from 'class-validator';

export class CreateGoalDto {
  @IsUUID('4')
  id!: string;

  @IsString()
  @Length(1, 80)
  name!: string;

  @IsInt()
  @Min(1)
  target_amount!: number;

  /** YYYY-MM-DD; không được ở quá khứ. */
  @IsOptional()
  @IsISO8601()
  deadline?: string;

  @IsOptional()
  @IsString()
  @Length(1, 40)
  icon?: string;
}

export class UpdateGoalDto {
  @IsOptional()
  @IsString()
  @Length(1, 80)
  name?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  target_amount?: number;

  /** Số tuyệt đối, KHÔNG phải số cộng thêm (tránh cộng trùng khi retry). */
  @IsOptional()
  @IsInt()
  @Min(0)
  saved_amount?: number;

  @IsOptional()
  @IsISO8601()
  deadline?: string;

  @IsOptional()
  @IsString()
  @Length(1, 40)
  icon?: string;

  @IsOptional()
  @IsBoolean()
  is_completed?: boolean;

  @IsInt()
  @Min(1)
  rev!: number;
}
