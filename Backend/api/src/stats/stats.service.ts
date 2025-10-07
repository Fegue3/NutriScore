import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { addDays, parseISO } from 'date-fns';

/* ------------------------------ Utils & Types ------------------------------ */

function toUTC00(d: Date) {
  // normaliza para 00:00 UTC
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function round(n: number, p = 0) {
  const f = Math.pow(10, p);
  return Math.round(n * f) / f;
}

function calcAge(dob?: Date | null): number | null {
  if (!dob) return null;
  const now = new Date();
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const m = now.getUTCMonth() - dob.getUTCMonth();
  if (m < 0 || (m === 0 && now.getUTCDate() < dob.getUTCDate())) age--;
  return age;
}

function activityMultiplier(level?: string | null): number {
  if (!level) return 1.2; // sedentário por defeito
  const v = level.toLowerCase();
  if (['sedentary', 'sedentário', 'sedentaria'].some(k => v.includes(k))) return 1.2;
  if (['light', 'leve'].some(k => v.includes(k))) return 1.375;
  if (['moderate', 'moderado', 'moderada'].some(k => v.includes(k))) return 1.55;
  if (['active', 'ativo', 'activa', 'ativa'].some(k => v.includes(k))) return 1.725;
  if (['very', 'muito'].some(k => v.includes(k))) return 1.9;
  return 1.2;
}

function mifflinStJeor(
  sex: 'MALE' | 'FEMALE' | 'OTHER' | null | undefined,
  kg?: number | null,
  cm?: number | null,
  age?: number | null,
): number | null {
  if (!kg || !cm || !age) return null;
  // BMR = 10*kg + 6.25*cm - 5*age + s
  // s: MALE = +5, FEMALE = -161, OTHER = média (-78)
  const s = sex === 'MALE' ? 5 : sex === 'FEMALE' ? -161 : -78;
  return 10 * Number(kg) + 6.25 * Number(cm) - 5 * Number(age) + s;
}

type RecommendBasis =
  | { source: 'goals'; kcal: number; macroPerc: { protein: number; carb: number; fat: number } }
  | { source: 'bmr'; bmr: number; activityFactor: number; kcal: number; macroPerc: { protein: number; carb: number; fat: number } };

export type DayRow = {
  date: string;
  kcal: number;
  protein_g: number;
  carb_g: number;
  fat_g: number;
  sugars_g: number;
  fiber_g: number;
  salt_g: number;
};

/* --------------------------------- Service -------------------------------- */

@Injectable()
export class StatsService {
  constructor(private prisma: PrismaService) {}

  // ===================== LEITURA (consumo do user) =====================

  /** GET /stats/daily */
  async getDaily(userId: string, dateISO?: string) {
    const d = dateISO ? parseISO(dateISO) : new Date();
    const day = toUTC00(d);

    // cache-first; se não existir, materializa e usa
    const row =
      (await this.prisma.dailyStats.findUnique({
        where: { userId_date: { userId, date: day } },
      })) ?? (await this.recomputeDay(userId, day));

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
  async getRange(userId: string, fromISO: string, toISO: string): Promise<DayRow[]> {
    const from = toUTC00(parseISO(fromISO));
    const to = toUTC00(parseISO(toISO));

    // garantir materialização dos dias em falta
    const days: Date[] = [];
    for (let d = from; d <= to; d = addDays(d, 1)) days.push(d);

    const existing = await this.prisma.dailyStats.findMany({
      where: { userId, date: { gte: from, lte: to } },
    });
    const existingKey = new Set(existing.map(r => r.date.toISOString()));
    const missing = days.filter(d => !existingKey.has(d.toISOString()));

    if (missing.length) {
      await Promise.all(missing.map(d => this.recomputeDay(userId, d)));
    }

    const rows = await this.prisma.dailyStats.findMany({
      where: { userId, date: { gte: from, lte: to } },
      orderBy: { date: 'asc' },
    });

    return rows.map(r => ({
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

  // ===================== RECOMENDADOS (objetivos do user) =====================

  /** GET /stats/recommended */
  async getRecommended(userId: string) {
    const goals = await this.prisma.userGoals.findUnique({ where: { userId } });

    // 1) calorias-alvo
    let kcalTarget: number | null = goals?.dailyCalories ?? null;
    let basis: RecommendBasis;

    if (kcalTarget == null) {
      // estimar com BMR + atividade
      const age = calcAge(goals?.dateOfBirth ?? null);
      const bmr = mifflinStJeor(
        (goals?.sex as any) ?? null,
        goals?.currentWeightKg ? Number(goals.currentWeightKg) : null,
        goals?.heightCm ?? null,
        age,
      );
      const af = activityMultiplier(goals?.activityLevel ?? null);
      kcalTarget = bmr ? Math.round(bmr * af) : 2000;

      const macroPerc = {
        protein: goals?.proteinPercent ?? 20,
        fat: goals?.fatPercent ?? 30,
        carb:
          goals?.carbPercent ??
          (100 - (goals?.proteinPercent ?? 20) - (goals?.fatPercent ?? 30)),
      };

      basis = { source: 'bmr', bmr: bmr ?? 0, activityFactor: af, kcal: kcalTarget, macroPerc };
    } else {
      const macroPerc = {
        protein: goals?.proteinPercent ?? 20,
        fat: goals?.fatPercent ?? 30,
        carb:
          goals?.carbPercent ??
          (100 - (goals?.proteinPercent ?? 20) - (goals?.fatPercent ?? 30)),
      };
      basis = { source: 'goals', kcal: kcalTarget, macroPerc };
    }

    // 2) percentagens -> gramas
    const perc = (basis as any).macroPerc as { protein: number; carb: number; fat: number };

    let protein_g: number;
    if (!goals?.proteinPercent && goals?.currentWeightKg) {
      // afinamento por peso (1.6 g/kg), com limites 15–35% das kcal
      const p = Number(goals.currentWeightKg) * 1.6;
      const pPct = (p * 4) / (kcalTarget as number) * 100;
      const adjPct = Math.min(35, Math.max(15, pPct));
      protein_g = round(((kcalTarget as number) * (adjPct / 100)) / 4);
      const fatPct = goals?.fatPercent ?? 30;
      const carbPct = 100 - adjPct - fatPct;
      perc.protein = adjPct;
      perc.carb = carbPct;
      perc.fat = fatPct;
    } else {
      protein_g = round(((kcalTarget as number) * (perc.protein / 100)) / 4);
    }

    const fat_g = round(((kcalTarget as number) * (perc.fat / 100)) / 9);
    const carb_g = round(((kcalTarget as number) * (perc.carb / 100)) / 4);

    // 3) limites/recomendações adicionais
    const sugars_g_max = round(((kcalTarget as number) * 0.10) / 4); // <10% kcal
    const satFat_g_max = round(((kcalTarget as number) * 0.10) / 9); // <10% kcal
    const salt_g_max = 5; // g/dia
    const fiber_g = Math.max(25, round(14 * ((kcalTarget as number) / 1000))); // ~14g/1000 kcal

    return {
      units: { energy: 'kcal', mass: 'g', salt: 'g' },
      basis,
      targets: {
        kcal: kcalTarget,
        protein_g,
        carb_g,
        fat_g,
        sugars_g_max,
        fiber_g,
        salt_g_max,
        satFat_g_max,
      },
      macros_percent: {
        protein: round(perc.protein, 1),
        carb: round(perc.carb, 1),
        fat: round(perc.fat, 1),
      },
      preferences: {
        lowSalt: goals?.lowSalt ?? false,
        lowSugar: goals?.lowSugar ?? false,
        vegetarian: goals?.vegetarian ?? false,
        vegan: goals?.vegan ?? false,
      },
    };
  }

  // ===================== MATERIALIZAÇÃO & BREAKDOWN =====================

  /** Recalcula e persiste o somatório do dia (DailyStats) */
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

  /** Agregados por tipo de refeição (para UI detalhada) */
  private async sumByMeal(userId: string, dayUTC00: Date) {
    const meals = await this.prisma.meal.findMany({
      where: { userId, date: dayUTC00 },
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
