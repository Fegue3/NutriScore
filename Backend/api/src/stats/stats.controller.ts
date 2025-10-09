// src/stats/stats.controller.ts
import { Controller, Get, Query, UseGuards, Req } from '@nestjs/common';
import { StatsService } from './stats.service';
import { DailyDto } from './dto/daily.dto';
import { RangeDto } from './dto/range.dto';
import { DayNutrientsDto } from './dto/day-nutrients.dto';
import { AccessTokenGuard } from '../auth/auth.guards';
import { Request } from 'express';

@UseGuards(AccessTokenGuard)
@Controller('stats')
export class StatsController {
  constructor(private readonly stats: StatsService) {}

  @Get('daily')
  async daily(@Query() dto: DailyDto, @Req() req: Request) {
    const userId = (req.user as any)?.sub as string;
    return this.stats.getDaily({
      userId,
      dateISO: dto.date ?? this.stats.todayISO(),
    });
  }

  @Get('range')
  async range(@Query() dto: RangeDto, @Req() req: Request) {
    const userId = (req.user as any)?.sub as string;
    return this.stats.getRange({
      userId,
      fromISO: dto.from,
      toISO: dto.to,
    });
  }

  @Get('day-nutrients')
  async dayNutrients(@Query() dto: DayNutrientsDto, @Req() req: Request) {
    const userId = (req.user as any)?.sub as string;
    const dateISO = dto.date ?? this.stats.todayISO();
    const day = await this.stats.getDaily({ userId, dateISO });
    // reduz a payload para o card de macros/calorias
    return {
      date: day.date,
      goalKcal: day.goalKcal,
      consumedKcal: day.consumedKcal,
      macros: day.macros,
    };
  }
  @Get('recommended')
  async recommended(@Req() req: Request) {
    const userId = (req.user as any)?.sub as string; // igual ao resto do teu projeto
    return this.stats.getRecommended(userId);
  }
}
