// src/calories/calories.controller.ts
import { Controller, Get, Query, Req, UseGuards, UnauthorizedException } from '@nestjs/common';
import { Request } from 'express';
import { CaloriesService } from './calories.service';
import { AccessTokenGuard } from '../auth/auth.guards';
import { IsOptional, IsString, Matches } from 'class-validator';

interface AuthLike { id?: string; userId?: string; sub?: string; email?: string }
interface AuthenticatedRequest extends Request { user?: AuthLike }

// AAAA-MM-DD
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

export class DailyQueryDto {
  @IsOptional()
  @Matches(ISO_DATE, { message: 'date must be YYYY-MM-DD' })
  date?: string;

  @IsOptional()
  @IsString()
  tz?: string; // ex: Europe/Lisbon
}

export class RangeQueryDto {
  @Matches(ISO_DATE, { message: 'start must be YYYY-MM-DD' })
  start!: string;

  @Matches(ISO_DATE, { message: 'end must be YYYY-MM-DD' })
  end!: string;

  @IsOptional()
  @IsString()
  tz?: string;
}

function getUserIdFromReq(req: AuthenticatedRequest): string {
  const u = (req.user ?? {}) as AuthLike;
  const userId = u.id ?? u.userId ?? u.sub;
  if (!userId) throw new UnauthorizedException('Invalid token payload: missing user id');
  return userId;
}

@Controller('api/calories')
@UseGuards(AccessTokenGuard)
export class CaloriesController {
  constructor(private service: CaloriesService) {}

  @Get('daily')
  async daily(@Req() req: AuthenticatedRequest, @Query() q: DailyQueryDto) {
    const userId = getUserIdFromReq(req);
    return this.service.getCaloriesForDay(userId, q.date, q.tz ?? 'Europe/Lisbon');
  }

  @Get('range')
  async range(@Req() req: AuthenticatedRequest, @Query() q: RangeQueryDto) {
    const userId = getUserIdFromReq(req);
    return this.service.getCaloriesForRange(userId, q.start, q.end, q.tz ?? 'Europe/Lisbon');
  }
}
