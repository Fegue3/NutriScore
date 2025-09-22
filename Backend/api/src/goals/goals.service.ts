// src/goals/goals.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';

@Injectable()
export class GoalsService {
  constructor(private prisma: PrismaService) {}

  async upsertGoals(userId: string, data: any) {
    const toDec = (v?: number) => (v == null ? undefined : new Prisma.Decimal(v));

    return this.prisma.userGoals.upsert({
      where: { userId },
      update: {
        sex: data.sex,                          // enum 'Sex'
        dateOfBirth: data.dateOfBirth ? new Date(data.dateOfBirth) : undefined,
        heightCm: data.heightCm,
        currentWeightKg: toDec(data.currentWeightKg),
        targetWeightKg: toDec(data.targetWeightKg),
        targetDate: data.targetDate ? new Date(data.targetDate) : undefined,
        activityLevel: data.activityLevel,      // "sedentary" | ...
        lowSalt: data.lowSalt,
        lowSugar: data.lowSugar,
        vegetarian: data.vegetarian,
        vegan: data.vegan,
        allergens: data.allergens,
        dailyCalories: data.dailyCalories,
        carbPercent: data.carbPercent,
        proteinPercent: data.proteinPercent,
        fatPercent: data.fatPercent,
      },
      create: {
        userId,
        sex: data.sex,
        dateOfBirth: data.dateOfBirth ? new Date(data.dateOfBirth) : undefined,
        heightCm: data.heightCm,
        currentWeightKg: toDec(data.currentWeightKg),
        targetWeightKg: toDec(data.targetWeightKg),
        targetDate: data.targetDate ? new Date(data.targetDate) : undefined,
        activityLevel: data.activityLevel,
        lowSalt: data.lowSalt ?? false,
        lowSugar: data.lowSugar ?? false,
        vegetarian: data.vegetarian ?? false,
        vegan: data.vegan ?? false,
        allergens: data.allergens,
        dailyCalories: data.dailyCalories,
        carbPercent: data.carbPercent,
        proteinPercent: data.proteinPercent,
        fatPercent: data.fatPercent,
      },
    });
  }

  async getGoals(userId: string) {
    return this.prisma.userGoals.findUnique({ where: { userId } });
  }
}
