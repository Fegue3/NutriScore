// src/meals/meals.module.ts
import { Module } from '@nestjs/common';
import { MealsService } from './meals.service';
import { MealsController } from './meals.controller';
import { PrismaService } from '../prisma/prisma.service';

@Module({
  controllers: [MealsController],
  providers: [MealsService, PrismaService],
})
export class MealsModule {}
