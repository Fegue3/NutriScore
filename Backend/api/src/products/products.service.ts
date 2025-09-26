import { Injectable, HttpException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { OffProduct, offFetchByBarcode, offSearch } from './off.client';

const REFRESH_MS = 30 * 24 * 3600 * 1000; // 30 dias

@Injectable()
export class ProductsService {
  constructor(private prisma: PrismaService) {}

  private mapOffToDb(p: OffProduct) {
    const n = p.nutriments ?? {};
    const D = (v?: number | null) =>
      v == null ? null : new Prisma.Decimal(Number(v.toFixed(2)));

    return {
      barcode: p.code,
      name: p.product_name ?? `${p.brands ?? 'Produto'} ${p.code}`,
      brand: p.brands ?? null,
      quantity: p.quantity ?? null,
      servingSize: p.serving_size ?? null,
      imageUrl: p.image_front_url ?? null,
      countries: p.countries ?? null,

      nutriScore: (p.nutriscore_grade ?? undefined)?.toUpperCase() as any,
      nutriScoreScore: p.nutriscore_score ?? null,
      novaGroup: p.nova_group ?? null,
      ecoScore: (p.ecoscore_grade ?? null)?.toUpperCase() ?? null,

      categories: p.categories ?? null,
      labels: p.labels ?? null,
      allergens: p.allergens ?? null,
      ingredientsText: p.ingredients_text ?? null,

      energyKcal_100g: n['energy-kcal_100g'] ?? null,
      proteins_100g: D(n.proteins_100g),
      carbs_100g: D(n.carbohydrates_100g),
      sugars_100g: D(n.sugars_100g),
      fat_100g: D(n.fat_100g),
      satFat_100g: D(n['saturated-fat_100g']),
      fiber_100g: D(n.fiber_100g),
      salt_100g: D(n.salt_100g),
      sodium_100g: D(n.sodium_100g),

      energyKcal_serv: n['energy-kcal_serving'] ?? null,
      proteins_serv: D(n.proteins_serving),
      carbs_serv: D(n.carbohydrates_serving),
      sugars_serv: D(n.sugars_serving),
      fat_serv: D(n.fat_serving),
      satFat_serv: D(n['saturated-fat_serving']),
      fiber_serv: D(n.fiber_serving),
      salt_serv: D(n.salt_serving),
      sodium_serv: D(n.sodium_serving),
    };
  }

  private isFresh(date?: Date | null) {
    if (!date) return false;
    return Date.now() - date.getTime() < REFRESH_MS;
  }

  // Upsert em Product + grava ProductHistory (se userId vier)
  async getByBarcode(barcode: string, userId?: string) {
    const cached = await this.prisma.product.findUnique({ where: { barcode } });

    if (!cached || !this.isFresh(cached.lastFetchedAt)) {
      const off = await offFetchByBarcode(barcode);
      if (!off) {
        if (cached) return cached;
        throw new HttpException('Produto não encontrado', 404);
      }

      const mapped = this.mapOffToDb(off);
      const upserted = await this.prisma.product.upsert({
        where: { barcode },
        update: { ...mapped, lastFetchedAt: new Date(), off_raw: off as any },
        create: { ...mapped, lastFetchedAt: new Date(), off_raw: off as any },
      });

      if (userId) {
        await this.prisma.productHistory.create({
          data: {
            userId,
            barcode: upserted.barcode,
            nutriScore: upserted.nutriScore ?? null,
            calories: upserted.energyKcal_100g ?? null,
            proteins: upserted.proteins_100g ?? null,
            carbs: upserted.carbs_100g ?? null,
            fat: upserted.fat_100g ?? null,
        },
        });
      }

      return upserted;
    }

    if (userId) {
      await this.prisma.productHistory.create({
        data: {
          userId,
          barcode: cached.barcode,
          nutriScore: cached.nutriScore ?? null,
          calories: cached.energyKcal_100g ?? null,
          proteins: cached.proteins_100g ?? null,
          carbs:    cached.carbs_100g ?? null,
          fat:      cached.fat_100g ?? null,
        },
      });
    }

    return cached;
  }

  // ------------ Pesquisa local (para híbrida) ------------
  async searchLocal(q: string, page = 1, pageSize = 20) {
    const skip = (page - 1) * pageSize;
    const where: Prisma.ProductWhereInput = {
      OR: [
        { name: { contains: q, mode: Prisma.QueryMode.insensitive } },
        { brand: { contains: q, mode: Prisma.QueryMode.insensitive } },
        { categories: { contains: q, mode: Prisma.QueryMode.insensitive } },
      ],
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.product.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: [{ nutriScore: 'asc' }, { name: 'asc' }],
      }),
      this.prisma.product.count({ where }),
    ]);

    return { items, total, page, pageSize };
  }

  // ------------ Sugestões locais (rápidas) ------------
  async suggestLocal(q: string, limit = 8) {
    if (!q?.trim()) return { items: [], total: 0 };
    const where: Prisma.ProductWhereInput = {
      OR: [
        { name: { contains: q, mode: Prisma.QueryMode.insensitive } },
        { brand: { contains: q, mode: Prisma.QueryMode.insensitive } },
        { categories: { contains: q, mode: Prisma.QueryMode.insensitive } },
      ],
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.product.findMany({
        where,
        take: limit,
        orderBy: [{ nutriScore: 'asc' }, { name: 'asc' }],
      }),
      this.prisma.product.count({ where }),
    ]);
    return { items, total };
  }

  // ------------ Pesquisa confirmada (vai à OFF agora) ------------
  async searchConfirm(q: string, page = 1, pageSize = 20) {
    const off = await offSearch(q, page, pageSize);

    const upserts = off.products.map((p) =>
      this.prisma.product.upsert({
        where: { barcode: p.code },
        update: { ...this.mapOffToDb(p), lastFetchedAt: new Date(), off_raw: p as any },
        create: { ...this.mapOffToDb(p), lastFetchedAt: new Date(), off_raw: p as any },
      }),
    );
    await this.prisma.$transaction(upserts);

    const barcodes = off.products.map((p) => p.code);
    const items = await this.prisma.product.findMany({
      where: { barcode: { in: barcodes } },
      orderBy: [{ nutriScore: 'asc' }, { name: 'asc' }],
      take: pageSize,
    });

    return {
      items,
      total: off.count ?? items.length,
      page,
      pageSize,
      source: 'OFF+cache',
    };
  }

  // ------------ Pesquisa híbrida (local + enrichment async) ------------
  async searchHybrid(q: string, page = 1, pageSize = 20) {
    const local = await this.searchLocal(q, page, pageSize);
    try {
      const off = await offSearch(q, 1, Math.min(20, pageSize));
      const upserts = off.products.slice(0, pageSize).map((p) =>
        this.prisma.product.upsert({
          where: { barcode: p.code },
          update: { ...this.mapOffToDb(p), lastFetchedAt: new Date(), off_raw: p as any },
          create: { ...this.mapOffToDb(p), lastFetchedAt: new Date(), off_raw: p as any },
        }),
      );
      this.prisma.$transaction(upserts).catch(() => {});
    } catch {
      // ignora erros da OFF
    }
    return local;
  }

  // ------------ Favoritos ------------
  async toggleFavorite(userId: string, barcode: string) {
    try {
      await this.prisma.favoriteProduct.delete({
        where: { userId_barcode: { userId, barcode } },
      });
      return { favorited: false };
    } catch {
      await this.prisma.favoriteProduct.create({ data: { userId, barcode } });
      return { favorited: true };
    }
  }
}
