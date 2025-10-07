// src/meals/meals.service.ts
import { Injectable } from '@nestjs/common';
import { Prisma, Unit, MealType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMealsDto } from './meals.dto';
import { StatsService } from '../stats/stats.service';

function toUtcMidnight(ymd: string): Date {
  // ymd é YYYY-MM-DD no timezone do user → normalizamos para UTC 00:00
  const [y, m, d] = ymd.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d, 0, 0, 0, 0));
}

@Injectable()
export class MealsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stats: StatsService,
  ) {}

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
        at: meal.date,                 // dia da refeição (UTC 00:00)
        meal: meal.type,               // tipo
        name: it.customFood?.name ?? it.product?.name ?? 'Produto',
        brand: it.customFood?.brand ?? it.product?.brand ?? null,
        barcode: it.product?.barcode ?? null,
        nutriScore: it.product?.nutriScore ?? null,

        // totais “congelados”
        calories: it.kcal ?? null,
        protein: it.protein ?? null,
        carbs: it.carb ?? null,
        fat: it.fat ?? null,
        sugars: it.sugars ?? null,
        fiber: it.fiber ?? null,
        salt: it.salt ?? null,

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
    const relCreates: Prisma.MealItemCreateInput[] = [];

    body.items.forEach((it, idx) => {
      const kcal = it.calories ?? null;
      const protein = it.protein ?? null;
      const carb = it.carbs ?? null;
      const fat = it.fat ?? null;
      const sugars = it.sugars ?? null;
      const salt = it.salt ?? null;

      const gramsTotal = it.unit === Unit.GRAM ? new Prisma.Decimal(it.quantity) : null;

      const base: Omit<Prisma.MealItemCreateInput, 'meal' | 'product' | 'customFood'> = {
        position: idx + 1,
        unit: it.unit,
        quantity: new Prisma.Decimal(it.quantity),
        gramsTotal,
        kcal,
        protein: protein != null ? new Prisma.Decimal(protein) : null,
        carb:    carb    != null ? new Prisma.Decimal(carb)    : null,
        fat:     fat     != null ? new Prisma.Decimal(fat)     : null,
        sugars:  sugars  != null ? new Prisma.Decimal(sugars)  : null,
        salt:    salt    != null ? new Prisma.Decimal(salt)    : null,
      };

      if (it.barcode) {
        relCreates.push({
          ...base,
          meal: { connect: { id: meal.id } },
          product: { connect: { barcode: it.barcode } },
        });
      } else if (it.customFoodId) {
        relCreates.push({
          ...base,
          meal: { connect: { id: meal.id } },
          customFood: { connect: { id: it.customFoodId } },
        });
      } else {
        relCreates.push({
          ...base,
          meal: { connect: { id: meal.id } },
        });
      }
    });

    await this.prisma.$transaction(relCreates.map((data) => this.prisma.mealItem.create({ data })));

    // materializa DailyStats do dia
    await this.stats.recomputeDay(userId, date);

    return this.getDay(userId, body.date);
  }

  /** PATCH /meals/items/:id — atualiza campos do item (quantidade, caches, etc.) */
  async updateItem(itemId: string, patch: Partial<{
    unit: Unit;
    quantity: number | string;
    calories: number | null;
    protein: number | null;
    carbs: number | null;
    fat: number | null;
    sugars: number | null;
    fiber: number | null;
    salt: number | null;
  }>) {
    // metadados para recompute
    const meta = await this.prisma.mealItem.findUnique({
      where: { id: itemId },
      select: { meal: { select: { userId: true, date: true } } },
    });
    if (!meta?.meal) return;

    const data: Prisma.MealItemUpdateInput = {};
    if (patch.unit) data.unit = patch.unit;
    if (patch.quantity != null) {
      const q = new Prisma.Decimal(patch.quantity as any);
      data.quantity = q;
      data.gramsTotal = (patch.unit ?? undefined) === Unit.GRAM || (patch.unit == null && undefined)
        ? q
        : null;
    }
    if ('calories' in patch) data.kcal  = patch.calories;
    if ('protein'  in patch) data.protein = patch.protein  != null ? new Prisma.Decimal(patch.protein) : null;
    if ('carbs'    in patch) data.carb    = patch.carbs    != null ? new Prisma.Decimal(patch.carbs)   : null;
    if ('fat'      in patch) data.fat     = patch.fat      != null ? new Prisma.Decimal(patch.fat)     : null;
    if ('sugars'   in patch) data.sugars  = patch.sugars   != null ? new Prisma.Decimal(patch.sugars)  : null;
    if ('fiber'    in patch) data.fiber   = patch.fiber    != null ? new Prisma.Decimal(patch.fiber)   : null;
    if ('salt'     in patch) data.salt    = patch.salt     != null ? new Prisma.Decimal(patch.salt)    : null;

    await this.prisma.mealItem.update({ where: { id: itemId }, data });

    await this.stats.recomputeDay(meta.meal.userId, meta.meal.date);
  }

  /** PATCH /meals/:id — mover refeição de dia e/ou tipo */
  async moveMeal(mealId: string, opts: { newDate?: string; newType?: MealType }) {
    const meal = await this.prisma.meal.findUnique({
      where: { id: mealId },
      select: { id: true, userId: true, date: true, type: true },
    });
    if (!meal) return;

    const oldDay = meal.date;
    const newDay = opts.newDate ? toUtcMidnight(opts.newDate) : meal.date;
    const newType = opts.newType ?? meal.type;

    await this.prisma.meal.update({
      where: { id: mealId },
      data: { date: newDay, type: newType },
    });

    // recomputar dia antigo e novo (se mudou)
    await this.stats.recomputeDay(meal.userId, oldDay);
    if (newDay.getTime() !== oldDay.getTime()) {
      await this.stats.recomputeDay(meal.userId, newDay);
    }
  }

  /** DELETE /meals/:mealId — apaga a Meal inteira */
  async deleteMeal(mealId: string) {
    // ler metadados antes
    const meta = await this.prisma.meal.findUnique({
      where: { id: mealId },
      select: { userId: true, date: true },
    });
    if (!meta) return;

    await this.prisma.meal.delete({ where: { id: mealId } });

    await this.stats.recomputeDay(meta.userId, meta.date);
  }

  /** DELETE /meals/:mealId/items/:itemId — apaga um item da Meal */
  async deleteMealItem(mealId: string, itemId: string) {
    const meta = await this.prisma.meal.findUnique({
      where: { id: mealId },
      select: { userId: true, date: true },
    });
    if (!meta) return;

    await this.prisma.mealItem.delete({ where: { id: itemId } });

    await this.stats.recomputeDay(meta.userId, meta.date);
  }

  /** DELETE /meals/items/:itemId — apaga item por id, sem precisar do mealId */
  async deleteItemById(itemId: string) {
    const item = await this.prisma.mealItem.findUnique({
      where: { id: itemId },
      select: { meal: { select: { userId: true, date: true } } },
    });
    if (!item?.meal) return;

    await this.prisma.mealItem.delete({ where: { id: itemId } });

    await this.stats.recomputeDay(item.meal.userId, item.meal.date);
  }
}
