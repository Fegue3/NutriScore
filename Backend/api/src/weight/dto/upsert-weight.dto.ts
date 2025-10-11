import { IsOptional, IsDateString, IsNumber, Min, Max, IsString } from 'class-validator';

export class UpsertWeightDto {
  /** YYYY-MM-DD (UTC 00:00). Se omitido, usa hoje. */
  @IsOptional()
  @IsDateString()
  date?: string;

  /** Peso em kg (0 < x ≤ 400) */
  @IsNumber()
  @Min(0.1)
  @Max(400)
  weightKg!: number;

  /** Ex.: "manual" | "import" | "sync" */
  @IsOptional()
  @IsString()
  source?: string;

  /** Nota opcional */
  @IsOptional()
  @IsString()
  note?: string;
}
