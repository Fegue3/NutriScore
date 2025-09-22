// src/goals/goals.controller.ts
import { Controller, Put, Get, Body, UseGuards, Req } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/auth.guards';
import { GoalsService } from './goals.service';

@Controller('me/goals')
@UseGuards(AccessTokenGuard)
export class GoalsController {
  constructor(private readonly goalsService: GoalsService) {}

  @Put()
  async upsertGoals(@Body() body: any, @Req() req: any) {
    const userId = (req.user as any).sub; // vem do JWT 'jwt-access'
    return this.goalsService.upsertGoals(userId, body);
  }

  @Get()
  async getGoals(@Req() req: any) {
    const userId = (req.user as any).sub;
    return this.goalsService.getGoals(userId);
  }
}
