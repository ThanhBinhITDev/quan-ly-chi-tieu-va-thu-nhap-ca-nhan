import {
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Length,
} from 'class-validator';

export const DEVICE_PLATFORMS = ['android', 'ios', 'web'] as const;

export class RegisterDeviceDto {
  @IsUUID('4')
  id!: string;

  @IsIn(DEVICE_PLATFORMS)
  platform!: (typeof DEVICE_PLATFORMS)[number];

  @IsOptional()
  @IsString()
  @Length(1, 4096)
  push_token?: string;

  @IsOptional()
  @IsString()
  @Length(1, 40)
  app_version?: string;
}
