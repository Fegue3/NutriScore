import { Module } from '@nestjs/common';
import { MealsController } from './meals.controller';
import { MealsService } from './meals.service';
import { PrismaService } from '../prisma/prisma.service';

@Module({
  controllers: [MealsController],
  providers: [MealsService, PrismaService],
  exports: [MealsService],
})
export class MealsModule {}
