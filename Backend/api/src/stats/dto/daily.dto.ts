import { IsDateString, IsOptional } from 'class-validator';

export class DailyQueryDto {
  @IsOptional()
  @IsDateString()
  date?: string; // YYYY-MM-DD (opcional -> hoje por defeito)
}
