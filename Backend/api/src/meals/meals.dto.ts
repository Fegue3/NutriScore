// src/meals/meals.dto.ts
import { IsArray, IsEnum, IsInt, IsISO8601, IsNumber, IsOptional, IsPositive, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { MealType, Unit } from '@prisma/client';

export class CreateMealItemDto {
  @IsOptional() @IsString()
  barcode?: string;              // product barcode (liga ao Product)

  @IsOptional() @IsString()
  customFoodId?: string;         // alternativa: item custom

  @IsEnum(Unit)
  unit!: Unit;                   // GRAM | ML | PIECE

  @IsNumber()
  @IsPositive()
  quantity!: number;             // quantidade na unidade dada

  // caches opcionais (kcal/macros) – se vierem do cliente, guardamos
  @IsOptional() @IsInt()
  calories?: number;

  @IsOptional() @IsNumber()
  protein?: number;
  @IsOptional() @IsNumber()
  carbs?: number;
  @IsOptional() @IsNumber()
  fat?: number;
  @IsOptional() @IsNumber()
  sugars?: number;
  @IsOptional() @IsNumber()
  salt?: number;
}

export class CreateMealsDto {
  /** 'YYYY-MM-DD' do dia visível no ecrã */
  @IsISO8601({ strict: true })
  date!: string;

  /** Tipo de refeição (BREAKFAST/LUNCH/SNACK/DINNER) */
  @IsEnum(MealType)
  type!: MealType;

  @IsArray() @ValidateNested({ each: true })
  @Type(() => CreateMealItemDto)
  items!: CreateMealItemDto[];
}
