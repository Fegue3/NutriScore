import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { MealsService } from './meals.service';
import { CreateMealDto } from './meals.dto';
import { AccessTokenGuard } from '../auth/auth.guards';
import { Request } from 'express';

@Controller('meals')
@UseGuards(AccessTokenGuard)
export class MealsController {
  constructor(private readonly mealsService: MealsService) {}

  @Post()
  async create(@Req() req: Request, @Body() dto: CreateMealDto) {
    const userId = (req.user as any).sub;
    return this.mealsService.createMeal(userId, dto);
  }

  @Get()
  async findAll(@Req() req: Request, @Query('date') date?: string) {
    const userId = (req.user as any).sub;
    if (date) {
      return this.mealsService.findMealsByDate(userId, date);
    }
    return this.mealsService.findAllMeals(userId);
  }
}
