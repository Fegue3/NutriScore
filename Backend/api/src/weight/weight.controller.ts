import { Controller, Get, Put, Body, Query, UseGuards, Req } from '@nestjs/common';
import { Request } from 'express';
import { AccessTokenGuard } from '../auth/auth.guards';
import { WeightService } from './weight.service';
import { UpsertWeightDto } from './dto/upsert-weight.dto';
import { WeightRangeDto } from './dto/weight-range.dto';

@UseGuards(AccessTokenGuard)
@Controller('weight')
export class WeightController {
  constructor(private readonly weight: WeightService) {}

  // Upsert do peso num dia (default: hoje UTC), e atualiza UserGoals.currentWeightKg
  @Put()
  async upsert(@Body() dto: UpsertWeightDto, @Req() req: Request) {
    const userId = (req.user as any)?.sub as string;
    return this.weight.upsertWeight(userId, dto);
  }

  // Série temporal para gráficos
  @Get()
  async range(@Query() q: WeightRangeDto, @Req() req: Request) {
    const userId = (req.user as any)?.sub as string;
    return this.weight.getRange(userId, q.from, q.to);
  }

  // Último registo (para pré-preencher UI)
  @Get('latest')
  async latest(@Req() req: Request) {
    const userId = (req.user as any)?.sub as string;
    return this.weight.getLatest(userId);
  }
}
