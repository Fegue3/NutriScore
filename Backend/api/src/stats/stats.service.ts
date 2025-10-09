// src/stats/stats.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MealType, Prisma } from '@prisma/client';

type ISODate = string; // "YYYY-MM-DD"

type MacroTotals = {
  kcal: number;
  protein: number;
  carb: number;
  fat: number;
  sugars: number;
  fiber: number;
  salt: number;
};

type ByMeal = Partial<Record<MealType, MacroTotals>>;

function zero(): MacroTotals {
  return { kcal: 0, protein: 0, carb: 0, fat: 0, sugars: 0, fiber: 0, salt: 0 };
}
function add(a: MacroTotals, b: Partial<MacroTotals>): MacroTotals {
  return {
    kcal: a.kcal + (b.kcal ?? 0),
    protein: a.protein + (b.protein ?? 0),
    carb: a.carb + (b.carb ?? 0),
    fat: a.fat + (b.fat ?? 0),
    sugars: a.sugars + (b.sugars ?? 0),
    fiber: a.fiber + (b.fiber ?? 0),
    salt: a.salt + (b.salt ?? 0),
  };
}
const num = (v: Prisma.Decimal | number | null | undefined) =>
  v == null ? 0 : Number(v);

@Injectable()
export class StatsService {
  constructor(private readonly prisma: PrismaService) { }

  /** ISO de hoje (UTC) no formato YYYY-MM-DD */
  todayISO(): ISODate {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = `${now.getUTCMonth() + 1}`.padStart(2, '0');
    const d = `${now.getUTCDate()}`.padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  /** Converte YYYY-MM-DD → Date em 00:00:00 UTC */
  private startOfDayUTC(iso: ISODate): Date {
    return new Date(`${iso}T00:00:00.000Z`);
  }

  /** Avança n dias a partir de um ISO (pode ser negativo). */
  private addDaysISO(iso: ISODate, delta: number): ISODate {
    const d = this.startOfDayUTC(iso);
    d.setUTCDate(d.getUTCDate() + delta);
    const y = d.getUTCFullYear();
    const m = `${d.getUTCMonth() + 1}`.padStart(2, '0');
    const day = `${d.getUTCDate()}`.padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  // ====== NOVO: materialização/refresh de DailyStats ======
  /**
   * Recalcula e materializa os totais diários (DailyStats) para um user e um dia.
   * Se não houver items no dia, apaga a linha de cache (evita dados “fantasma”).
   */
  async recomputeDay(userId: string, dateUTC: Date): Promise<void> {
    // Ler todas as refeições do dia com os campos necessários dos items
    const meals = await this.prisma.meal.findMany({
      where: { userId, date: dateUTC },
      select: {
        items: {
          select: {
            kcal: true,
            protein: true,
            carb: true,
            fat: true,
            sugars: true,
            fiber: true,
            salt: true,
          },
        },
      },
    });

    // Agregar
    const totals = meals.reduce((acc, m) => {
      for (const it of m.items) {
        acc.kcal += num(it.kcal);
        acc.protein += num(it.protein);
        acc.carb += num(it.carb);
        acc.fat += num(it.fat);
        acc.sugars += num(it.sugars);
        acc.fiber += num(it.fiber);
        acc.salt += num(it.salt);
      }
      return acc;
    }, zero());

    const isEmpty =
      meals.length === 0 ||
      (totals.kcal === 0 &&
        totals.protein === 0 &&
        totals.carb === 0 &&
        totals.fat === 0 &&
        totals.sugars === 0 &&
        totals.fiber === 0 &&
        totals.salt === 0);

    // Se não houver nada no dia → remover cache (se existir)
    if (isEmpty) {
      await this.prisma.dailyStats.deleteMany({
        where: { userId, date: dateUTC },
      });
      return;
    }

    // Caso contrário, upsert do snapshot agregado
    await this.prisma.dailyStats.upsert({
      where: { userId_date: { userId, date: dateUTC } },
      create: {
        userId,
        date: dateUTC,
        kcal: totals.kcal,
        protein: totals.protein,
        carb: totals.carb,
        fat: totals.fat,
        sugars: totals.sugars,
        fiber: totals.fiber,
        salt: totals.salt,
      },
      update: {
        kcal: totals.kcal,
        protein: totals.protein,
        carb: totals.carb,
        fat: totals.fat,
        sugars: totals.sugars,
        fiber: totals.fiber,
        salt: totals.salt,
        updatedAt: new Date(),
      },
    });

  }

  // ====== API existente ======
  async getDaily(params: { userId: string; dateISO: ISODate }) {
    const { userId, dateISO } = params;
    const date = this.startOfDayUTC(dateISO);

    // Goal kcal do utilizador (pode ser null)
    const goals = await this.prisma.userGoals.findUnique({
      where: { userId },
      select: { dailyCalories: true },
    });
    const goalKcal = goals?.dailyCalories ?? null;

    // 1) Tenta via Meal/MealItem (fonte de verdade)
    const meals = await this.prisma.meal.findMany({
      where: { userId, date },
      select: {
        type: true,
        items: {
          select: {
            kcal: true,
            protein: true,
            carb: true,
            fat: true,
            sugars: true,
            fiber: true,
            salt: true,
          },
        },
      },
      orderBy: { type: 'asc' },
    });

    // Agregar por refeição + totais
    const byMeal: ByMeal = {};
    let dayTotals = zero();

    for (const m of meals) {
      let acc = zero();
      for (const it of m.items) {
        const addIt: MacroTotals = {
          kcal: num(it.kcal),
          protein: num(it.protein),
          carb: num(it.carb),
          fat: num(it.fat),
          sugars: num(it.sugars),
          fiber: num(it.fiber),
          salt: num(it.salt),
        };
        acc = add(acc, addIt);
      }
      byMeal[m.type] = acc;
      dayTotals = add(dayTotals, acc);
    }

    // 2) Se não houver Meals (ou zero), tenta DailyStats (cache denormalizada)
    if (meals.length === 0 || dayTotals.kcal === 0) {
      const ds = await this.prisma.dailyStats.findUnique({
        where: {
          userId_date: { userId, date },
        },
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
      if (ds) {
        dayTotals = {
          kcal: num(ds.kcal),
          protein: num(ds.protein),
          carb: num(ds.carb),
          fat: num(ds.fat),
          sugars: num(ds.sugars),
          fiber: num(ds.fiber),
          salt: num(ds.salt),
        };
      }
    }

    const consumedKcal = dayTotals.kcal;
    const macros = {
      protein: dayTotals.protein,
      carb: dayTotals.carb,
      fat: dayTotals.fat,
      sugars: dayTotals.sugars,
      fiber: dayTotals.fiber,
      salt: dayTotals.salt,
    };

    // Garante chaves para todas as refeições
    for (const t of Object.values(MealType)) {
      if (!byMeal[t]) byMeal[t] = zero();
    }

    return {
      date: dateISO,
      goalKcal,
      consumedKcal,
      byMeal,
      macros,
    };
  }

  async getRange(params: { userId: string; fromISO: ISODate; toISO: ISODate }) {
    const { userId, fromISO, toISO } = params;

    // Normaliza e valida ordem
    const days: ISODate[] = [];
    let cur = fromISO;
    while (true) {
      days.push(cur);
      if (cur === toISO) break;
      cur = this.addDaysISO(cur, 1);
      // Segurança: limita a 92 dias (≈ 3 meses)
      if (days.length > 92) break;
    }

    const results = await Promise.all(
      days.map((d) => this.getDaily({ userId, dateISO: d })),
    );

    return {
      from: fromISO,
      to: toISO,
      days: results.map((r) => ({
        date: r.date,
        consumedKcal: r.consumedKcal,
        goalKcal: r.goalKcal,
        macros: r.macros,
      })),
    };
  }
}
