// src/stats/stats.module.ts
import { Module } from '@nestjs/common';
import { StatsController } from './stats.controller';
import { StatsService } from './stats.service';
import { PrismaModule } from '../prisma/prisma.module';
import { CaloriesModule } from '../calories/calories.module';

@Module({
  imports: [PrismaModule, CaloriesModule],
  controllers: [StatsController],
  providers: [StatsService],
  exports: [StatsService],
})
export class StatsModule {}
