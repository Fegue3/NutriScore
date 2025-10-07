// src/stats/dto/daily.dto.ts
import { IsOptional, IsDateString } from 'class-validator';

export class DailyDto {
  /**
   * Data canónica (YYYY-MM-DD). Se omitido, assume hoje (UTC 00:00).
   */
  @IsOptional()
  @IsDateString()
  date?: string;
}
