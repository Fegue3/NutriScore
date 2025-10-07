// src/stats/dto/day-nutrients.dto.ts
import { IsOptional, IsDateString } from 'class-validator';

export class DayNutrientsDto {
  @IsOptional()
  @IsDateString()
  date?: string;
}
