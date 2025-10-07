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

@UseGuards(AccessTokenGuard)
@Controller('stats')
export class StatsController {
  constructor(private readonly stats: StatsService) {}

  @Get('daily')
  async daily(@Req() req: Request, @Query('date') date?: string) {
    const user = (req as any).user;
    const userId = user?.sub ?? user?.id;
    if (!userId) throw new BadRequestException('Utilizador inválido.');
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
    const user = (req as any).user;
    const userId = user?.sub ?? user?.id;
    if (!userId) throw new BadRequestException('Utilizador inválido.');
    return this.stats.getRange(userId, from, to);
  }
}
