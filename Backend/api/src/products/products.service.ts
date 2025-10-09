// src/products/products.service.ts
import { Injectable, HttpException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { OffProduct, offFetchByBarcode, offSearch } from './off.client';

const REFRESH_MS = 30 * 24 * 3600 * 1000; // 30 dias

type DateLike = string | Date | null | undefined;

@Injectable()
export class ProductsService {
  constructor(private prisma: PrismaService) {}

  /* ===================== Utils ===================== */

  // remove undefined (JSON puro) — evita PrismaClientValidationError no off_raw
  private sanitizeJson<T>(obj: T): T {
    return JSON.parse(JSON.stringify(obj));
  }

  // number -> Decimal (2 casas) ou null
  private D(v?: number | null) {
    return v == null ? null : new Prisma.Decimal(Number(v.toFixed(2)));
  }

  // converte string OFF -> enum Prisma (A..E) ou null
  private toNutriGrade(g?: string | null) {
    if (!g) return null;
    const u = g.trim().toUpperCase();
    return (['A', 'B', 'C', 'D', 'E'] as const).includes(u as any) ? (u as any) : null;
  }

  private isFresh(date?: DateLike) {
    if (!date) return false;
    const d = typeof date === 'string' ? new Date(date) : date;
    return Date.now() - d.getTime() < REFRESH_MS;
  }

  // ⚠️ Serialização segura: BigInt -> string (recursivo)
  private replaceBigInts(value: any): any {
    if (value === null || value === undefined) return value;
    if (typeof value === 'bigint') return value.toString();
    if (Array.isArray(value)) return value.map((v) => this.replaceBigInts(v));
    if (typeof value === 'object') {
      return Object.fromEntries(
        Object.entries(value).map(([k, v]) => [k, this.replaceBigInts(v)]),
      );
    }
    return value;
  }

  /* ===================== Mapping OFF -> DB ===================== */

  private mapOffToDb(p: OffProduct) {
    const n = p.nutriments ?? {};

    return {
      barcode: p.code,
      name: p.product_name ?? `${p.brands ?? 'Produto'} ${p.code}`,
      brand: p.brands ?? null,
      quantity: p.quantity ?? null,
      servingSize: p.serving_size ?? null,
      imageUrl: p.image_front_url ?? null,
      countries: p.countries ?? null,

      // (fix) enum seguro
      nutriScore: this.toNutriGrade(p.nutriscore_grade),
      nutriScoreScore: p.nutriscore_score ?? null,
      novaGroup: p.nova_group ?? null,
      ecoScore: (p.ecoscore_grade ?? null)?.toUpperCase() ?? null,

      categories: p.categories ?? null,
      labels: p.labels ?? null,
      allergens: p.allergens ?? null,
      ingredientsText: p.ingredients_text ?? null,

      energyKcal_100g: n['energy-kcal_100g'] ?? null,
      proteins_100g: this.D(n.proteins_100g),
      carbs_100g: this.D(n.carbohydrates_100g),
      sugars_100g: this.D(n.sugars_100g),
      fat_100g: this.D(n.fat_100g),
      satFat_100g: this.D(n['saturated-fat_100g']),
      fiber_100g: this.D(n.fiber_100g),
      salt_100g: this.D(n.salt_100g),
      sodium_100g: this.D(n.sodium_100g),

      energyKcal_serv: n['energy-kcal_serving'] ?? null,
      proteins_serv: this.D(n.proteins_serving),
      carbs_serv: this.D(n.carbohydrates_serving),
      sugars_serv: this.D(n.sugars_serving),
      fat_serv: this.D(n.fat_serving),
      satFat_serv: this.D(n['saturated-fat_serving']),
      fiber_serv: this.D(n.fiber_serving),
      salt_serv: this.D(n.salt_serving),
      sodium_serv: this.D(n.sodium_serving),
    };
  }

  /* ========= Histórico: evitar duplicado consecutivo ========= */

  /** Grava no histórico apenas se o último registo do utilizador tiver barcode diferente */
  private async addHistoryIfNotDuplicate(
    userId: string,
    snapshot: {
      barcode: string;
      nutriScore: string | null;
      calories: number | null;
      proteins: Prisma.Decimal | null;
      carbs: Prisma.Decimal | null;
      fat: Prisma.Decimal | null;
    },
  ) {
    const last = await this.prisma.productHistory.findFirst({
      where: { userId },
      orderBy: { scannedAt: 'desc' },
      select: { id: true, barcode: true },
    });

    if (last && last.barcode === snapshot.barcode) {
      // não cria duplicado consecutivo; idempotente
      return { skipped: true, id: last.id };
    }

    const created = await this.prisma.productHistory.create({
      data: {
        userId,
        barcode: snapshot.barcode,
        nutriScore: (snapshot.nutriScore as any) ?? null,
        calories: snapshot.calories ?? null,
        proteins: snapshot.proteins ?? null,
        carbs: snapshot.carbs ?? null,
        fat: snapshot.fat ?? null,
      },
    });
    return { skipped: false, id: created.id };
  }

  /* ===================== API ===================== */

  // Upsert em Product + grava ProductHistory (se userId vier)
  async getByBarcode(barcode: string, userId?: string) {
    const cached = await this.prisma.product.findUnique({ where: { barcode } });

    if (!cached || !this.isFresh(cached.lastFetchedAt)) {
      const off = await offFetchByBarcode(barcode);

      if (!off) {
        if (cached) return cached;

        // (fix) fallback a partir do histórico quando OFF/cache falham
        const lastHist = userId
          ? await this.prisma.productHistory.findFirst({
              where: { userId, barcode },
              orderBy: { scannedAt: 'desc' },
            })
          : null;

        if (lastHist) {
          // devolve DTO mínimo compatível com ProductDetail.fromJson no frontend
          return {
            barcode,
            name: `Produto ${barcode}`,
            brand: null,
            quantity: null,
            servingSize: null,
            imageUrl: null,
            countries: null,

            nutriScore: lastHist.nutriScore ?? null,
            nutriScoreScore: null,
            novaGroup: null,
            ecoScore: null,

            categories: null,
            labels: null,
            allergens: null,
            ingredientsText: null,

            energyKcal_100g: lastHist.calories ?? null,
            proteins_100g: lastHist.proteins ?? null,
            carbs_100g: lastHist.carbs ?? null,
            sugars_100g: null,
            fat_100g: lastHist.fat ?? null,
            satFat_100g: null,
            fiber_100g: null,
            salt_100g: null,
            sodium_100g: null,

            energyKcal_serv: null,
            proteins_serv: null,
            carbs_serv: null,
            sugars_serv: null,
            fat_serv: null,
            satFat_serv: null,
            fiber_serv: null,
            salt_serv: null,
            sodium_serv: null,

            lastFetchedAt: null,
            createdAt: new Date(),
            updatedAt: new Date(),
            off_raw: null,
          };
        }

        throw new HttpException('Produto não encontrado', 404);
      }

      const mapped = this.mapOffToDb(off);
      const offRaw = this.sanitizeJson(off);

      const upserted = await this.prisma.product.upsert({
        where: { barcode },
        update: { ...mapped, lastFetchedAt: new Date(), off_raw: offRaw },
        create: { ...mapped, lastFetchedAt: new Date(), off_raw: offRaw },
      });

      if (userId) {
        await this.addHistoryIfNotDuplicate(userId, {
          barcode: upserted.barcode,
          nutriScore: (upserted.nutriScore as any) ?? null,
          calories: upserted.energyKcal_100g ?? null,
          proteins: upserted.proteins_100g ?? null,
          carbs: upserted.carbs_100g ?? null,
          fat: upserted.fat_100g ?? null,
        });
      }

      return upserted;
    }

    if (userId) {
      await this.addHistoryIfNotDuplicate(userId, {
        barcode: cached.barcode,
        nutriScore: (cached.nutriScore as any) ?? null,
        calories: cached.energyKcal_100g ?? null,
        proteins: cached.proteins_100g ?? null,
        carbs: cached.carbs_100g ?? null,
        fat: cached.fat_100g ?? null,
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

    // 🔥 remove nome vazio / só espaços
    const clean = items.filter(
      (it) => (it.name ?? '').replace(/\s+/g, '').length > 0,
    );

    return { items: clean, total, page, pageSize };
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

    //remove nome vazio / só espaços
    const clean = items.filter(
      (it) => (it.name ?? '').replace(/\s+/g, '').length > 0,
    );

    return { items: clean, total };
  }

  // ------------ Pesquisa confirmada (vai à OFF agora) ------------
  async searchConfirm(q: string, page = 1, pageSize = 20) {
    const off = await offSearch(q, page, pageSize);

    // 🔥 só produtos com código e nome “real”
    const valid = off.products.filter(
      (p) => !!p.code && (p.product_name ?? '').replace(/\s+/g, '').length > 0,
    );

    const upserts = valid.map((p) => {
      const mapped = this.mapOffToDb(p);
      const offRaw = this.sanitizeJson(p);
      return this.prisma.product.upsert({
        where: { barcode: p.code },
        update: { ...mapped, lastFetchedAt: new Date(), off_raw: offRaw },
        create: { ...mapped, lastFetchedAt: new Date(), off_raw: offRaw },
      });
    });

    if (upserts.length) {
      await this.prisma.$transaction(upserts);
    }

    const barcodes = valid.map((p) => p.code);
    const items = await this.prisma.product.findMany({
      where: { barcode: { in: barcodes } },
      orderBy: [{ name: 'asc' }],
      take: pageSize,
    });

    // 🔥 remove nome vazio / só espaços
    const clean = items.filter(
      (it) => (it.name ?? '').replace(/\s+/g, '').length > 0,
    );

    return {
      items: clean,
      total: off.count ?? clean.length,
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
      const valid = off.products.filter((p) => !!p.code).slice(0, pageSize);
      const upserts = valid.map((p) => {
        const mapped = this.mapOffToDb(p);
        const offRaw = this.sanitizeJson(p);
        return this.prisma.product.upsert({
          where: { barcode: p.code },
          update: { ...mapped, lastFetchedAt: new Date(), off_raw: offRaw },
          create: { ...mapped, lastFetchedAt: new Date(), off_raw: offRaw },
        });
      });
      if (upserts.length) {
        this.prisma.$transaction(upserts).catch(() => {});
      }
    } catch {
      // ignora erros da OFF
    }
    return local;
  }

  /* ===================== FAVORITOS ===================== */

  // Lista favoritos com join a Product
  async listFavorites(userId: string, page = 1, pageSize = 20, q?: string) {
    const skip = (page - 1) * pageSize;

    const whereProduct: Prisma.ProductWhereInput | undefined = q
      ? {
          OR: [
            { name: { contains: q, mode: Prisma.QueryMode.insensitive } },
            { brand: { contains: q, mode: Prisma.QueryMode.insensitive } },
          ],
        }
      : undefined;

    const whereFav: Prisma.FavoriteProductWhereInput = {
      userId,
      ...(whereProduct
        ? {
            product: whereProduct,
          }
        : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.favoriteProduct.findMany({
        where: whereFav,
        skip,
        take: pageSize,
        orderBy: { createdAt: 'desc' },
        include: {
          product: {
            select: {
              barcode: true,
              name: true,
              brand: true,
              imageUrl: true,
              nutriScore: true,
              energyKcal_100g: true,
            },
          },
        },
      }),
      this.prisma.favoriteProduct.count({ where: whereFav }),
    ]);

    const items = rows.map((r) => ({
      barcode: r.product?.barcode ?? r.barcode,
      name: r.product?.name ?? null,
      brand: r.product?.brand ?? null,
      imageUrl: r.product?.imageUrl ?? null,
      nutriScore: r.product?.nutriScore ?? null,
      energyKcal_100g: r.product?.energyKcal_100g ?? null,
      createdAt: r.createdAt,
    }));

    return { items, total, page, pageSize };
  }

  // Estado (boolean) para um produto
  async isFavorited(userId: string, barcode: string) {
    const found = await this.prisma.favoriteProduct.findUnique({
      where: { userId_barcode: { userId, barcode } },
      select: { userId: true },
    });
    return { favorited: !!found };
  }

  // Add idempotente
  async addFavorite(userId: string, barcode: string) {
    try {
      await this.prisma.favoriteProduct.create({
        data: { userId, barcode },
      });
      return { favorited: true };
    } catch (e: any) {
      // Se já existir (unique), continua true
      return { favorited: true };
    }
  }

  // Remove idempotente
  async removeFavorite(userId: string, barcode: string) {
    try {
      await this.prisma.favoriteProduct.delete({
        where: { userId_barcode: { userId, barcode } },
      });
      return { favorited: false };
    } catch {
      return { favorited: false };
    }
  }

  // Toggle (mantido)
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

  /* ===================== HISTÓRICO ===================== */

  // ------------ Histórico (lista) ------------
  async listHistory(
    userId: string,
    page = 1,
    pageSize = 20,
    from?: string,
    to?: string,
  ) {
    const skip = (page - 1) * pageSize;

    const where: Prisma.ProductHistoryWhereInput = {
      userId,
      AND: [
        from ? { scannedAt: { gte: new Date(from) } } : {},
        to ? { scannedAt: { lte: new Date(to) } } : {},
      ],
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.productHistory.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { scannedAt: 'desc' },
        include: {
          product: {
            select: {
              barcode: true,
              name: true,
              brand: true,
              imageUrl: true,
              nutriScore: true,
              energyKcal_100g: true,
            },
          },
        },
      }),
      this.prisma.productHistory.count({ where }),
    ]);

    const safeItems = rows.map((r) =>
      this.replaceBigInts({
        ...r,
        id:
          typeof (r as any).id === 'bigint'
            ? (r as any).id.toString()
            : (r as any).id,
      }),
    );

    return {
      items: safeItems,
      total,
      page,
      pageSize,
    };
  }
}
