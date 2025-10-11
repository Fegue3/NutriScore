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

  /**
   * Cria SEMPRE um novo registo no weightLog (histórico real),
   * e atualiza o currentWeightKg em UserGoals — tudo numa transação.
   *
   * Observações:
   * - Requer que o modelo `weightLog` NÃO tenha `@@unique([userId, day])`.
   * - Campos esperados em weightLog: id, userId, day(Date), weightKg(Decimal/Float), source?, note?, createdAt(DateTime @default(now())).
   */
  async upsertWeight(userId: string, dto: UpsertWeightDto) {
    const dayISO = dto.date ?? this.todayISO();
    const day = this.startOfDayUTC(dayISO);

    const kg = Number(dto.weightKg);
    if (!Number.isFinite(kg) || kg <= 0 || kg > 400) {
      throw new BadRequestException('weightKg inválido');
    }

    const created = await this.prisma.$transaction(async (tx) => {
      // 1) cria SEMPRE um novo ponto no log
      const log = await tx.weightLog.create({
        data: {
          userId,
          day,                   // âncora diária (00:00Z)
          weightKg: kg,
          source: dto.source ?? 'manual',
          note: dto.note,
          // createdAt vem por default(now())
        },
        select: {
          id: true,
          day: true,
          weightKg: true,
          source: true,
          note: true,
          createdAt: true,
        },
      });

      // 2) atualiza/garante metas com o peso atual
      await tx.userGoals.upsert({
        where: { userId },
        create: { userId, currentWeightKg: kg },
        update: { currentWeightKg: kg },
      });

      return log;
    });

    return {
      ok: true,
      log: {
        id: created.id,
        date: created.day.toISOString().slice(0, 10), // YYYY-MM-DD
        weightKg: Number(created.weightKg),
        source: created.source,
        note: created.note,
        createdAt: created.createdAt.toISOString(),
      },
    };
  }

  /**
   * Série temporal entre [from,to] (ambos inclusivos), ordenada por (day ASC, createdAt ASC).
   * Se existirem vários registos no mesmo dia, todos são devolvidos (para gráfico com variação intra-dia).
   */
  async getRange(userId: string, fromISO: ISODate, toISO: ISODate) {
    const from = this.startOfDayUTC(fromISO);
    const to = this.startOfDayUTC(toISO);

    const items = await this.prisma.weightLog.findMany({
      where: { userId, day: { gte: from, lte: to } },
      orderBy: [{ day: 'asc' }, { createdAt: 'asc' }],
      select: { day: true, weightKg: true, source: true, note: true, createdAt: true },
    });

    return {
      from: fromISO,
      to: toISO,
      points: items.map((w) => ({
        date: w.day.toISOString().slice(0, 10),          // ancora diária
        weightKg: Number(w.weightKg),
        source: w.source,
        note: w.note,
        createdAt: w.createdAt.toISOString(),            // timestamp exato (para mostrar horas)
      })),
    };
  }

  /**
   * Último registo do utilizador (mais recente por createdAt; em empate, por day).
   */
  async getLatest(userId: string) {
    const latest = await this.prisma.weightLog.findFirst({
      where: { userId },
      orderBy: [{ createdAt: 'desc' }, { day: 'desc' }],
      select: { day: true, weightKg: true, source: true, note: true, createdAt: true },
    });

    if (!latest) return { date: null, weightKg: null };

    return {
      date: latest.day.toISOString().slice(0, 10),
      weightKg: Number(latest.weightKg),
      source: latest.source,
      note: latest.note,
      createdAt: latest.createdAt.toISOString(),
    };
  }
}
