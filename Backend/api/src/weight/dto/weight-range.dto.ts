import { IsDateString } from 'class-validator';

export class WeightRangeDto {
  /** Inclusivo, YYYY-MM-DD */
  @IsDateString()
  from!: string;

  /** Inclusivo, YYYY-MM-DD */
  @IsDateString()
  to!: string;
}
