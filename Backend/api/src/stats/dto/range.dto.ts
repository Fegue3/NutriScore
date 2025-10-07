import { IsDateString } from 'class-validator';

export class RangeQueryDto {
  @IsDateString()
  from!: string; // YYYY-MM-DD

  @IsDateString()
  to!: string;   // YYYY-MM-DD
}
