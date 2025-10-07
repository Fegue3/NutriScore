import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { addDays, parseISO } from 'date-fns';

function toUTC00(d: Date) {
  // normaliza para 00:00 UTC
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

@Injectable()
export class StatsService {
  constructor(private prisma: PrismaService) {}

  // ===================== LEITURA =====================

  /** GET /stats/daily */
  async getDaily(userId: string, dateISO?: string) {
    const d = dateISO ? parseISO(dateISO) : new Date();
    const day = toUTC00(d);

    // 1) tenta materializado
    let row = await this.prisma.dailyStats.findUnique({
      where: { userId_date: { userId, date: day } },
    });

    // 2) se não existir, calcula on the fly e persiste
    if (!row) {
      row = await this.recomputeDay(userId, day);
    }

    // metas do utilizador (para progresso)
    const goals = await this.prisma.userGoals.findUnique({ where: { userId } });

    const goalsOut = goals?.dailyCalories
      ? {
          kcal: goals.dailyCalories,
          // percentuais -> gramas (4 kcal/g carb/protein, 9 kcal/g fat)
          protein_g: goals.proteinPercent
            ? Math.round((goals.dailyCalories * (goals.proteinPercent / 100)) / 4)
            : null,
          carb_g: goals.carbPercent
            ? Math.round((goals.dailyCalories * (goals.carbPercent / 100)) / 4)
            : null,
          fat_g: goals.fatPercent
            ? Math.round((goals.dailyCalories * (goals.fatPercent / 100)) / 9)
            : null,
        }
      : null;

    const totals = {
      kcal: row.kcal,
      protein_g: Number(row.protein),
      carb_g: Number(row.carb),
      fat_g: Number(row.fat),
      sugars_g: Number(row.sugars),
      fiber_g: Number(row.fiber),
      salt_g: Number(row.salt),
    };

    const progress =
      goalsOut &&
      goalsOut.kcal && {
        kcal: {
          used: totals.kcal,
          target: goalsOut.kcal,
          left: Math.max(0, goalsOut.kcal - totals.kcal),
          pct: goalsOut.kcal ? totals.kcal / goalsOut.kcal : null,
        },
        protein_g:
          goalsOut.protein_g != null
            ? {
                used: totals.protein_g,
                target: goalsOut.protein_g,
                left: Math.max(0, goalsOut.protein_g - totals.protein_g),
                pct: goalsOut.protein_g ? totals.protein_g / goalsOut.protein_g : null,
              }
            : null,
        carb_g:
          goalsOut.carb_g != null
            ? {
                used: totals.carb_g,
                target: goalsOut.carb_g,
                left: Math.max(0, goalsOut.carb_g - totals.carb_g),
                pct: goalsOut.carb_g ? totals.carb_g / goalsOut.carb_g : null,
              }
            : null,
        fat_g:
          goalsOut.fat_g != null
            ? {
                used: totals.fat_g,
                target: goalsOut.fat_g,
                left: Math.max(0, goalsOut.fat_g - totals.fat_g),
                pct: goalsOut.fat_g ? totals.fat_g / goalsOut.fat_g : null,
              }
            : null,
      };

    // byMeal (para UI detalhada)
    const byMeal = await this.sumByMeal(userId, day);

    return {
      date: day.toISOString().slice(0, 10),
      totals,
      byMeal,
      goals: goalsOut,
      progress,
    };
  }

  /** GET /stats/range */
  async getRange(userId: string, fromISO: string, toISO: string) {
    const from = toUTC00(parseISO(fromISO));
    const to = toUTC00(parseISO(toISO));

    // Garante materialização dos dias em falta
    const days: Date[] = [];
    for (let d = from; d <= to; d = addDays(d, 1)) days.push(d);

    const existing = await this.prisma.dailyStats.findMany({
      where: { userId, date: { gte: from, lte: to } },
    });
    const existingKey = new Set(existing.map((r) => r.date.toISOString()));
    const missing = days.filter((d) => !existingKey.has(d.toISOString()));
    if (missing.length) {
      await Promise.all(missing.map((d) => this.recomputeDay(userId, d)));
    }

    const rows = await this.prisma.dailyStats.findMany({
      where: { userId, date: { gte: from, lte: to } },
      orderBy: { date: 'asc' },
    });

    return rows.map((r) => ({
      date: r.date.toISOString().slice(0, 10),
      kcal: r.kcal,
      protein_g: Number(r.protein),
      carb_g: Number(r.carb),
      fat_g: Number(r.fat),
      sugars_g: Number(r.sugars),
      fiber_g: Number(r.fiber),
      salt_g: Number(r.salt),
    }));
  }

  // ===================== RECOMPUTE (usar após mutações) =====================

  /** recalcula e persiste o somatório do dia (DailyStats) */
  async recomputeDay(userId: string, dayUTC00: Date) {
    const items = await this.prisma.mealItem.findMany({
      where: { meal: { userId, date: dayUTC00 } },
      select: {
        kcal: true,
        protein: true,
        carb: true,
        fat: true,
        sugars: true,
        fiber: true,
        salt: true,
      },
    });

    const sum = items.reduce(
      (acc, it) => {
        acc.kcal += it.kcal ?? 0;
        acc.protein += Number(it.protein ?? 0);
        acc.carb += Number(it.carb ?? 0);
        acc.fat += Number(it.fat ?? 0);
        acc.sugars += Number(it.sugars ?? 0);
        acc.fiber += Number(it.fiber ?? 0);
        acc.salt += Number(it.salt ?? 0);
        return acc;
      },
      { kcal: 0, protein: 0, carb: 0, fat: 0, sugars: 0, fiber: 0, salt: 0 },
    );

    return this.prisma.dailyStats.upsert({
      where: { userId_date: { userId, date: dayUTC00 } },
      update: {
        kcal: sum.kcal,
        protein: sum.protein,
        carb: sum.carb,
        fat: sum.fat,
        sugars: sum.sugars,
        fiber: sum.fiber,
        salt: sum.salt,
      },
      create: {
        userId,
        date: dayUTC00,
        kcal: sum.kcal,
        protein: sum.protein,
        carb: sum.carb,
        fat: sum.fat,
        sugars: sum.sugars,
        fiber: sum.fiber,
        salt: sum.salt,
      },
    });
  }

  /** agregados por tipo de refeição, para o detalhe da UI */
  private async sumByMeal(userId: string, dayUTC00: Date) {
    const meals = await this.prisma.meal.findMany({
      where: { userId, date: dayUTC00 },
      select: {
        type: true,
        items: {
          select: {
            kcal: true, protein: true, carb: true, fat: true, sugars: true, fiber: true, salt: true,
          },
        },
      },
    });

    const res: Record<string, any> = {};
    for (const m of meals) {
      const s = m.items.reduce(
        (acc, it) => {
          acc.kcal += it.kcal ?? 0;
          acc.protein += Number(it.protein ?? 0);
          acc.carb += Number(it.carb ?? 0);
          acc.fat += Number(it.fat ?? 0);
          acc.sugars += Number(it.sugars ?? 0);
          acc.fiber += Number(it.fiber ?? 0);
          acc.salt += Number(it.salt ?? 0);
          return acc;
        },
        { kcal: 0, protein: 0, carb: 0, fat: 0, sugars: 0, fiber: 0, salt: 0 },
      );

      res[m.type] = {
        kcal: s.kcal,
        protein_g: s.protein,
        carb_g: s.carb,
        fat_g: s.fat,
        sugars_g: s.sugars,
        fiber_g: s.fiber,
        salt_g: s.salt,
      };
    }
    return res;
  }
}
