// src/meals/meals.service.ts
import { Injectable } from '@nestjs/common';
import { Prisma, MealType, Unit } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMealsDto } from './meals.dto';

function toUtcMidnight(ymd: string): Date {
  // ymd é YYYY-MM-DD no timezone do user → normalizamos para UTC 00:00
  // isto evita cair "no dia anterior/seguinte" por causa do TZ
  const [y, m, d] = ymd.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d, 0, 0, 0, 0));
}

@Injectable()
export class MealsService {
  constructor(private readonly prisma: PrismaService) {}

  /** GET /meals?date=YYYY-MM-DD — devolve o dia já com items+produto */
  async getDay(userId: string, ymd: string) {
    const date = toUtcMidnight(ymd);

    const meals = await this.prisma.meal.findMany({
      where: { userId, date },
      orderBy: { type: 'asc' },
      include: {
        items: {
          orderBy: { position: 'asc' },
          include: {
            product: true,
            customFood: true,
          },
        },
      },
    });

    // Normalizamos num formato flat que o frontend já entende
    const entries = meals.flatMap((meal) =>
      meal.items.map((it) => ({
        id: it.id,
        at: meal.date,                               // dia da refeição
        meal: meal.type,                             // tipo
        // nome/brand vêm do produto ou do customFood; se nada, 'Produto'
        name: it.customFood?.name ?? it.product?.name ?? 'Produto',
        brand: it.customFood?.brand ?? it.product?.brand ?? null,
        barcode: it.product?.barcode ?? null,
        nutriScore: it.product?.nutriScore ?? null,

        // totais/kcal/macros “congelados” no momento do registo (se existirem)
        calories: it.kcal ?? null,
        protein: it.protein ?? null,
        carbs: it.carb ?? null,
        fat: it.fat ?? null,

        // quantidade apresentada
        quantityGrams: it.unit === Unit.GRAM ? Number(it.quantity) : null,
        servings: it.unit === Unit.PIECE ? Number(it.quantity) : null,
        unit: it.unit,
      })),
    );

    const totalCalories = entries.reduce((s, e) => s + (Number(e.calories) || 0), 0);

    return {
      date: ymd,
      entries,
      totalCalories,
    };
  }

  /** POST /meals — adiciona items à refeição desse dia, criando/atualizando a Meal */
  async add(userId: string, body: CreateMealsDto) {
    const date = toUtcMidnight(body.date);

    // upsert da Meal do dia/tipo
    const meal = await this.prisma.meal.upsert({
      where: { userId_date_type: { userId, date, type: body.type } },
      create: { userId, date, type: body.type },
      update: {},
    });

    // construir creates de items
    const itemsData: Prisma.MealItemCreateManyMealInput[] = []; // para createMany de campos diretos
    const relCreates: Prisma.MealItemCreateInput[] = [];        // quando há relations (product/customFood)

    body.items.forEach((it, idx) => {
      // normalização auxiliar para os caches
      const kcal = it.calories ?? null;
      const protein = it.protein ?? null;
      const carb = it.carbs ?? null;
      const fat = it.fat ?? null;
      const sugars = it.sugars ?? null;
      const salt = it.salt ?? null;

      // gramsTotal: se unidade for GRAM, igual à quantidade; caso contrário null
      const gramsTotal =
        it.unit === Unit.GRAM ? new Prisma.Decimal(it.quantity) : null;

      if (it.barcode) {
        // Tem Product → precisamos do create com relation (não dá em createMany)
        relCreates.push({
          meal: { connect: { id: meal.id } },
          position: idx + 1,
          unit: it.unit,
          quantity: new Prisma.Decimal(it.quantity),
          gramsTotal,
          product: { connect: { barcode: it.barcode } }, // << AQUI ESTÁ A LIGAÇÃO CORRETA
          kcal,
          protein: protein ? new Prisma.Decimal(protein) : null,
          carb: carb ? new Prisma.Decimal(carb) : null,
          fat: fat ? new Prisma.Decimal(fat) : null,
          sugars: sugars ? new Prisma.Decimal(sugars) : null,
          salt: salt ? new Prisma.Decimal(salt) : null,
        });
      } else if (it.customFoodId) {
        relCreates.push({
          meal: { connect: { id: meal.id } },
          position: idx + 1,
          unit: it.unit,
          quantity: new Prisma.Decimal(it.quantity),
          gramsTotal,
          customFood: { connect: { id: it.customFoodId } },
          kcal,
          protein: protein ? new Prisma.Decimal(protein) : null,
          carb: carb ? new Prisma.Decimal(carb) : null,
          fat: fat ? new Prisma.Decimal(fat) : null,
          sugars: sugars ? new Prisma.Decimal(sugars) : null,
          salt: salt ? new Prisma.Decimal(salt) : null,
        });
      } else {
        // nenhum dos dois — criamos “solto” (sem relação), possível em alguns fluxos
        relCreates.push({
          meal: { connect: { id: meal.id } },
          position: idx + 1,
          unit: it.unit,
          quantity: new Prisma.Decimal(it.quantity),
          gramsTotal,
          kcal,
          protein: protein ? new Prisma.Decimal(protein) : null,
          carb: carb ? new Prisma.Decimal(carb) : null,
          fat: fat ? new Prisma.Decimal(fat) : null,
          sugars: sugars ? new Prisma.Decimal(sugars) : null,
          salt: salt ? new Prisma.Decimal(salt) : null,
        });
      }
    });

    // Criamos um a um (porque temos relations). Se quiseres performance máxima, dá para batch com createMany
    // mas perdes a parte do connect ao Product/CustomFood.
    await this.prisma.$transaction(
      relCreates.map((data) => this.prisma.mealItem.create({ data })),
    );

    // devolvemos o dia atualizado
    return this.getDay(userId, body.date);
  }

  async deleteMeal(mealId: string) {
    await this.prisma.meal.delete({ where: { id: mealId } });
  }

  async deleteMealItem(mealId: string, itemId: string) {
    await this.prisma.mealItem.delete({ where: { id: itemId, mealId } as any });
  }

  async deleteItemById(itemId: string) {
    await this.prisma.mealItem.delete({ where: { id: itemId } });
  }
}
