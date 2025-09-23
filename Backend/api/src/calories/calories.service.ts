// src/calories/calories.service.ts
import { Injectable, BadRequestException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parseISO, isValid, eachDayOfInterval } from 'date-fns';
import { toZonedTime, fromZonedTime, formatInTimeZone } from 'date-fns-tz';

type Sex = 'MALE' | 'FEMALE' | 'OTHER';
type Activity = 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active' | null;

@Injectable()
export class CaloriesService {
  constructor(private prisma: PrismaService) {}

  // ---------- Helpers básicos ----------
  private getAge(dob: Date): number {
    const diff = Date.now() - new Date(dob).getTime();
    return new Date(diff).getUTCFullYear() - 1970;
  }

  private mifflin(sex: Sex, wKg: number, hCm: number, age: number): number {
    const base = 10 * wKg + 6.25 * hCm - 5 * age;
    if (sex === 'MALE') return base + 5;
    if (sex === 'FEMALE') return base - 161;
    return base - 78;
  }

  private activityFactor(level: Activity): number {
    switch (level) {
      case 'sedentary':   return 1.2;
      case 'light':       return 1.375;
      case 'moderate':    return 1.55;
      case 'active':      return 1.725;
      case 'very_active': return 1.9;
      default:            return 1.2;
    }
  }

  /** devolve TDEE e o registo de metas (goals) */
  private async getTDEEAndGoals(userId: string) {
    if (!userId) throw new UnauthorizedException('Missing user id');

    const goals = await this.prisma.userGoals.findUnique({ where: { userId } });
    if (!goals) throw new NotFoundException('User has no goals set');

    const { sex, dateOfBirth, heightCm, currentWeightKg, activityLevel } = goals;
    if (!sex || !dateOfBirth || heightCm == null || currentWeightKg == null) {
      throw new BadRequestException('Missing biometrics');
    }

    const age = this.getAge(new Date(dateOfBirth));
    const bmr = this.mifflin(sex as Sex, Number(currentWeightKg), Number(heightCm), age);
    const tdee = Math.round(bmr * this.activityFactor(activityLevel as Activity));

    return { tdee, goals };
  }

  /**
   * Converte “um dia local” (YYYY-MM-DD) numa janela UTC [start,end].
   * Se dateStr não vier, usa o dia atual na TZ indicada.
   */
  private dayWindowUTC(dateStr: string | undefined, tz: string) {
    let localISODate: string;

    if (dateStr) {
      const d = parseISO(dateStr);
      if (!isValid(d)) throw new BadRequestException('Invalid date');
      localISODate = dateStr.slice(0, 10); // YYYY-MM-DD
    } else {
      const nowInTz = toZonedTime(new Date(), tz);
      localISODate = formatInTimeZone(nowInTz, tz, 'yyyy-MM-dd');
    }

    const startUtc = fromZonedTime(`${localISODate}T00:00:00.000`, tz);
    const endUtc   = fromZonedTime(`${localISODate}T23:59:59.999`, tz);
    return { startUtc, endUtc, localDateISO: localISODate };
  }

  // ---------- Nova lógica de objetivo (ajuste ao TDEE) ----------
  /**
   * Calcula o alvo de calorias ajustado às metas.
   * Prioridade:
   * 1) goals.dailyCalories (override manual)
   * 2) Se há targetWeight → calcula déficit/superávit a partir de targetDate
   *    com clamps seguros (cut: -300..-700, bulk: +250..+500).
   * 3) Sem targetDate → defaults (cut -500 / bulk +300).
   */
  private computeGoalCalories(tdee: number, goals: any): number {
    // 1) override manual
    if (goals.dailyCalories != null) {
      return Math.max(1000, Math.round(goals.dailyCalories)); // safety floor
    }

    const current = Number(goals.currentWeightKg);
    const target  = goals.targetWeightKg != null ? Number(goals.targetWeightKg) : null;

    // Se não há objetivo de peso → manutenção
    if (target == null || Number.isNaN(target)) {
      return tdee;
    }

    const diffKg = target - current; // negativo = perder, positivo = ganhar

    // Se diferença muito pequena (<0.5 kg), considera manutenção
    if (Math.abs(diffKg) < 0.5) return tdee;

    // kcal por kg ~ 7700
    const KCAL_PER_KG = 7700;

    // tenta usar targetDate, se existir e fizer sentido
    let days: number | null = null;
    if (goals.targetDate) {
      const td = new Date(goals.targetDate);
      const ms = td.getTime() - Date.now();
      const d  = Math.round(ms / (1000 * 60 * 60 * 24));
      if (d >= 3 && d <= 365 * 2) { // janela razoável
        days = d;
      }
    }

    // calcula ajuste diário sugerido
    let adjust: number;
    if (days) {
      adjust = (diffKg * KCAL_PER_KG) / days; // negativo = deficit, positivo = surplus
    } else {
      // defaults (quando sem data válida)
      adjust = diffKg < 0 ? -500 : 300;
    }

    // aplicar clamps saudáveis
    if (diffKg < 0) {
      // perda de peso: clamp -700..-300
      adjust = Math.max(-700, Math.min(-300, adjust));
    } else {
      // ganho de peso: clamp +250..+500
      adjust = Math.max(250, Math.min(500, adjust));
    }

    const goal = tdee + adjust;
    // arredondar aos 10 para UI estável e piso mínimo de 1200 kcal
    return Math.max(1200, Math.round(goal / 10) * 10);
  }

  // ---------- Endpoints públicos ----------
  /** 1) Um único dia */
  async getCaloriesForDay(userId: string, dateStr?: string, tz: string = 'UTC') {
    const { tdee, goals } = await this.getTDEEAndGoals(userId);
    const targetCalories = this.computeGoalCalories(tdee, goals);

    const { startUtc, endUtc, localDateISO } = this.dayWindowUTC(dateStr, tz);

    const meals = await this.prisma.mealItem.aggregate({
      _sum: { kcal: true },
      where: {
        meal: {
          userId,
          date: { gte: startUtc, lte: endUtc },
        },
      },
    });

    const consumed = Number(meals._sum.kcal ?? 0);
    const remainingRaw = targetCalories - consumed;

    return {
      date: localDateISO,
      timezone: tz,
      maintenanceCalories: tdee,   // opcional: útil para UI/diagnóstico
      targetCalories,               // << agora ajustado ao objetivo
      consumedCalories: consumed,
      remaining: Math.max(0, remainingRaw),
      overBy: remainingRaw < 0 ? Math.abs(remainingRaw) : 0,
    };
  }

  /** 2) Intervalo (inclusive) — série diária */
  async getCaloriesForRange(userId: string, start: string, end: string, tz: string = 'UTC') {
    if (!start || !end) throw new BadRequestException('start and end are required (YYYY-MM-DD)');

    const startParsed = parseISO(start);
    const endParsed   = parseISO(end);
    if (!isValid(startParsed) || !isValid(endParsed)) throw new BadRequestException('Invalid dates');
    if (endParsed < startParsed) throw new BadRequestException('end must be >= start');

    const { tdee, goals } = await this.getTDEEAndGoals(userId);
    const targetCalories = this.computeGoalCalories(tdee, goals);

    const days = eachDayOfInterval({ start: startParsed, end: endParsed });
    const results = [];

    for (const d of days) {
      const dayStr = d.toISOString().slice(0, 10);
      const { startUtc, endUtc, localDateISO } = this.dayWindowUTC(dayStr, tz);

      const meals = await this.prisma.mealItem.aggregate({
        _sum: { kcal: true },
        where: {
          meal: {
            userId,
            date: { gte: startUtc, lte: endUtc },
          },
        },
      });

      const consumed = Number(meals._sum.kcal ?? 0);
      const remainingRaw = targetCalories - consumed;

      results.push({
        date: localDateISO,
        timezone: tz,
        maintenanceCalories: tdee,
        targetCalories,
        consumedCalories: consumed,
        remaining: Math.max(0, remainingRaw),
        overBy: remainingRaw < 0 ? Math.abs(remainingRaw) : 0,
      });
    }

    return { start, end, timezone: tz, days: results };
  }
}
