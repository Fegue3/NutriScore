// src/stats/dto/range.dto.ts
import { IsDateString } from 'class-validator';

export class RangeDto {
  /**
   * Inclusivo. Formato YYYY-MM-DD (00:00 UTC).
   */
  @IsDateString()
  from!: string;

  /**
   * Inclusivo. Formato YYYY-MM-DD (00:00 UTC).
   */
  @IsDateString()
  to!: string;
}
