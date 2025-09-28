import {
  IsArray,
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';

export enum MealType {
  BREAKFAST = 'BREAKFAST',
  LUNCH = 'LUNCH',
  DINNER = 'DINNER',
  SNACK = 'SNACK',
}

export class CreateMealItemDto {
  @IsString()
  @IsNotEmpty()
  barcode!: string;

  @IsOptional()
  @IsNumber()
  calories?: number;

  @IsOptional()
  @IsNumber()
  protein?: number;

  @IsOptional()
  @IsNumber()
  carb?: number;

  @IsOptional()
  @IsNumber()
  fat?: number;

  @IsOptional()
  @IsNumber()
  sugars?: number;

  @IsOptional()
  @IsNumber()
  salt?: number;

  @IsOptional()
  @IsNumber()
  quantity?: number;
}

export class CreateMealDto {
  @IsEnum(MealType)
  type!: MealType;

  @IsDateString()
  date!: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsArray()
  items!: CreateMealItemDto[];
}
