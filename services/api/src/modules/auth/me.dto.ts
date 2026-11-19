import { IsIn, IsOptional, IsString, Length } from 'class-validator';

export const USER_PLANS = ['free', 'pro_month', 'pro_year', 'pro_student'] as const;

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @Length(1, 60)
  display_name?: string;

  @IsOptional()
  @IsString()
  @Length(3, 10)
  currency?: string;

  @IsOptional()
  @IsString()
  @Length(1, 60)
  timezone?: string;

  @IsOptional()
  @IsIn(USER_PLANS)
  plan?: (typeof USER_PLANS)[number];
}
