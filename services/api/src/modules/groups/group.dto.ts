import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Min,
  ValidateNested,
} from 'class-validator';

export const SPLIT_METHODS = ['equal', 'exact'] as const;

export class CreateGroupDto {
  @IsUUID('4')
  id!: string;

  @IsString()
  @Length(1, 80)
  name!: string;
}

export class JoinGroupDto {
  @IsString()
  @Length(6, 12)
  invite_code!: string;
}

export class ShareDto {
  @IsUUID('4')
  user_id!: string;

  @IsInt()
  @Min(0)
  share_amount!: number;
}

export class CreateSharedExpenseDto {
  @IsUUID('4')
  id!: string;

  @IsInt()
  @Min(1)
  amount!: number;

  @IsOptional()
  @IsString()
  @Length(0, 200)
  note?: string;

  @IsISO8601()
  occurred_on!: string;

  @IsOptional()
  @IsIn(SPLIT_METHODS)
  split_method?: (typeof SPLIT_METHODS)[number];

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ShareDto)
  shares!: ShareDto[];
}

export class SettleDto {
  @IsUUID('4')
  with_user_id!: string;

  @IsInt()
  @Min(1)
  amount!: number;
}
