import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertWeightDto } from './dto/upsert-weight.dto';

type ISODate = string; // YYYY-MM-DD

@Injectable()
export class WeightService {
  constructor(private readonly prisma: PrismaService) {}

  /** ISO de hoje (UTC) no formato YYYY-MM-DD */
  private todayISO(): ISODate {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, '0');
    const d = String(now.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  /** Converte YYYY-MM-DD → Date em 00:00:00 UTC */
  private startOfDayUTC(iso: ISODate): Date {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(iso)) {
      throw new BadRequestException('date must be YYYY-MM-DD');
    }
    return new Date(`${iso}T00:00:00.000Z`);
  }

  /** Upsert (userId, day) + update do currentWeightKg (UserGoals) numa transação */
  async upsertWeight(userId: string, dto: UpsertWeightDto) {
    const dayISO = dto.date ?? this.todayISO();
    const day = this.startOfDayUTC(dayISO);
    const kg = Number(dto.weightKg);
    if (!Number.isFinite(kg) || kg <= 0 || kg > 400) {
      throw new BadRequestException('weightKg inválido');
    }

    const log = await this.prisma.$transaction(async (tx) => {
      const upserted = await tx.weightLog.upsert({
        where: { userId_day: { userId, day } }, // compósito do @@unique
        create: {
          userId,
          day,
          weightKg: kg,
          source: dto.source ?? 'manual',
          note: dto.note,
        },
        update: {
          weightKg: kg,
          source: dto.source ?? 'manual',
          note: dto.note,
          createdAt: new Date(), // marca atualização
        },
      });

      // garante existência de UserGoals e atualiza peso atual
      await tx.userGoals.upsert({
        where: { userId },
        create: { userId, currentWeightKg: kg },
        update: { currentWeightKg: kg },
      });

      return upserted;
    });

    return {
      ok: true,
      log: { day: dayISO, weightKg: kg, source: log.source, note: log.note },
    };
  }

  /** Série temporal [from,to] (ambos inclusivos) ordenada */
  async getRange(userId: string, fromISO: ISODate, toISO: ISODate) {
    const from = this.startOfDayUTC(fromISO);
    const to = this.startOfDayUTC(toISO);

    const items = await this.prisma.weightLog.findMany({
      where: { userId, day: { gte: from, lte: to } },
      orderBy: { day: 'asc' },
      select: { day: true, weightKg: true, source: true, note: true },
    });

    return {
      from: fromISO,
      to: toISO,
      points: items.map((w) => ({
        date: w.day.toISOString().slice(0, 10),
        weightKg: Number(w.weightKg),
        source: w.source,
        note: w.note,
      })),
    };
  }

  /** Último registo do utilizador */
  async getLatest(userId: string) {
    const latest = await this.prisma.weightLog.findFirst({
      where: { userId },
      orderBy: { day: 'desc' },
      select: { day: true, weightKg: true, source: true, note: true },
    });
    if (!latest) return { date: null, weightKg: null };

    return {
      date: latest.day.toISOString().slice(0, 10),
      weightKg: Number(latest.weightKg),
      source: latest.source,
      note: latest.note,
    };
  }
}
