import {
  BadRequestException,
  Controller,
  Get,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { StatsService } from './stats.service';
import { AccessTokenGuard } from '../auth/auth.guards';

const ISO_DAY = /^\d{4}-\d{2}-\d{2}$/;

@UseGuards(AccessTokenGuard)
@Controller('stats')
export class StatsController {
  constructor(private readonly stats: StatsService) { }

  @Get('daily')
  async daily(@Req() req: Request, @Query('date') date?: string) {
    const user = (req as any).user;
    const userId = user?.sub ?? user?.id;
    if (!userId) throw new BadRequestException('Utilizador inválido.');

    if (date && !ISO_DAY.test(date)) {
      throw new BadRequestException("Formato inválido para 'date' (YYYY-MM-DD).");
    }

    return this.stats.getDaily(userId, date);
  }

  @Get('range')
  async range(
    @Req() req: Request,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    if (!from || !to) {
      throw new BadRequestException("Query 'from' e 'to' são obrigatórios (YYYY-MM-DD).");
    }
    if (!ISO_DAY.test(from) || !ISO_DAY.test(to)) {
      throw new BadRequestException("Formato inválido (usar YYYY-MM-DD).");
    }

    const user = (req as any).user;
    const userId = user?.sub ?? user?.id;
    if (!userId) throw new BadRequestException('Utilizador inválido.');

    return this.stats.getRange(userId, from, to);
  }
  @Get('recommended')
  async recommended(@Req() req: Request) {
    const user = (req as any).user;
    const userId = user?.sub ?? user?.id;
    if (!userId) throw new BadRequestException('Utilizador inválido.');
    return this.stats.getRecommended(userId);
  }
}
