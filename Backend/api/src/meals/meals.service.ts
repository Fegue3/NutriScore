import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMealDto } from './meals.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class MealsService {
  constructor(private prisma: PrismaService) {}

  async createMeal(userId: string, dto: CreateMealDto) {
    // 1. cria ou encontra meal (para o dia e tipo)
    let meal = await this.prisma.meal.findFirst({
      where: {
        userId,
        date: new Date(dto.date),
        type: dto.type,
      },
    });

    if (!meal) {
      meal = await this.prisma.meal.create({
        data: {
          userId,
          date: new Date(dto.date),
          type: dto.type,
          notes: dto.notes ?? null,
          totalKcal: 0,
        },
      });
    }

    let totalKcal = meal.totalKcal ?? 0;

    // 2. cria items
    for (const item of dto.items) {
      await this.prisma.mealItem.create({
        data: {
          mealId: meal.id,
          productBarcode: item.barcode, // schema usa productBarcode
          quantity: new Prisma.Decimal(item.quantity ?? 1), // Decimal no schema
          kcal: item.calories ?? 0,
          protein: item.protein ?? null,
          carb: item.carb ?? null,
          fat: item.fat ?? null,
          sugars: item.sugars ?? null,
          salt: item.salt ?? null,
        },
      });

      // soma calorias (frontend já envia o valor total!)
      if (item.calories) {
        totalKcal += item.calories;
      }

      // 3. grava também em product_history
      await this.prisma.productHistory.create({
        data: {
          userId,
          barcode: item.barcode,
          nutriScore: (item as any).nutriscore ?? null, // NutriGrade enum no schema
          calories: item.calories ?? 0,
          proteins: item.protein ?? null,
          carbs: item.carb ?? null,
          fat: item.fat ?? null,
          scannedAt: new Date(dto.date), // usa a data recebida
        },
      });
    }

    // 4. atualiza total kcal da refeição
    await this.prisma.meal.update({
      where: { id: meal.id },
      data: { totalKcal },
    });

    return this.findMealById(userId, meal.id);
  }

  async findMealById(userId: string, mealId: string) {
    return this.prisma.meal.findFirst({
      where: { id: mealId, userId },
      include: { items: true },
    });
  }

  async findAllMeals(userId: string) {
    return this.prisma.meal.findMany({
      where: { userId },
      include: { items: true },
      orderBy: [{ date: 'desc' }, { type: 'asc' }],
    });
  }

  async findMealsByDate(userId: string, date: string) {
    const target = new Date(date);
    const start = new Date(target.setHours(0, 0, 0, 0));
    const end = new Date(target.setHours(23, 59, 59, 999));

    return this.prisma.meal.findMany({
      where: {
        userId,
        date: { gte: start, lte: end },
      },
      include: { items: true },
      orderBy: [{ type: 'asc' }],
    });
  }
}
