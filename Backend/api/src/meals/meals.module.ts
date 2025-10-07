import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { MealsService } from './meals.service';
import { MealsController } from './meals.controller';
import { StatsModule } from '../stats/stats.module';

@Module({
  imports: [PrismaModule, StatsModule], 
  controllers: [MealsController],
  providers: [MealsService],
  exports: [MealsService],
})
export class MealsModule {}
