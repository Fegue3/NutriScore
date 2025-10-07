import { IsDateString, IsOptional } from 'class-validator';

export class DayNutrientsQueryDto {
  @IsDateString()
  date!: string; // YYYY-MM-DD (dia do utilizador, mas normalizamos a UTC 00:00)

  @IsOptional()
  tz?: string; // ex: 'Europe/Lisbon' (opcional, se quiseres tratar TZ depois)
}
