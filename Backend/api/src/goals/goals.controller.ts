import { Controller, Put, Get, Body, UseGuards, Req, HttpCode, HttpStatus } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/auth.guards';
import { GoalsService } from './goals.service';
import { IsBoolean, IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

// DTO com transformação de números (evita payload “limpo” pela ValidationPipe)
class GoalsDto {
  @IsOptional() @IsString() sex?: 'MALE' | 'FEMALE' | 'OTHER';

  @IsOptional() @Type(() => Number) @IsInt() @Min(50) @Max(260)
  heightCm?: number;

  @IsOptional() @Type(() => Number) @IsNumber()
  currentWeightKg?: number;

  @IsOptional() @Type(() => Number) @IsNumber()
  targetWeightKg?: number;

  @IsOptional() @IsString()
  activityLevel?: string;

  @IsOptional() @Type(() => Number) @IsInt()
  dailyCalories?: number;

  @IsOptional() @Type(() => Number) @IsInt()
  carbPercent?: number;

  @IsOptional() @Type(() => Number) @IsInt()
  proteinPercent?: number;

  @IsOptional() @Type(() => Number) @IsInt()
  fatPercent?: number;

  @IsOptional() @IsBoolean() lowSalt?: boolean;
  @IsOptional() @IsBoolean() lowSugar?: boolean;
  @IsOptional() @IsBoolean() vegetarian?: boolean;
  @IsOptional() @IsBoolean() vegan?: boolean;

  @IsOptional() @IsString() allergens?: string;

  @IsOptional() @IsString() dateOfBirth?: string; // ISO
  @IsOptional() @IsString() targetDate?: string;   // ISO
}

@UseGuards(AccessTokenGuard)
// 👉 escolhe UM dos dois, conforme uses ou não prefixo global 'api':
// @Controller('api/me')
@Controller('api/me')
export class GoalsController {
  constructor(private readonly goalsService: GoalsService) {}

  @Put('goals')
  @HttpCode(HttpStatus.OK)
  async upsertGoals(@Body() body: GoalsDto, @Req() req: any) {
    const userId = (req.user as any).sub;
    // DEBUG opcional para confirmares o body transformado:
    // console.log('PUT /api/me/goals dto =', body);
    await this.goalsService.upsertGoals(userId, body);
    return { ok: true };
  }

  @Get('goals')
  async getGoals(@Req() req: any) {
    const userId = (req.user as any).sub;
    return this.goalsService.getGoals(userId);
  }
}
