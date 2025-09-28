// src/products/products.controller.ts
import { Controller, Get, Param, Query, Req, Post, UseGuards, ParseIntPipe } from '@nestjs/common';
import { ProductsService } from './products.service';
import { SearchDto } from './dto/search.dto';
import { AccessTokenGuard } from '../auth/auth.guards';

@Controller('products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  // ---- ESTÁTICAS PRIMEIRO (evita colidir com :barcode) ----

  // Sugestões rápidas (só cache local)
  @Get('suggest')
  async suggest(@Query('q') q: string, @Query('limit', ParseIntPipe) limit = 8) {
    return this.products.suggestLocal(q, Number(limit));
  }

  // Pesquisa confirmada (vai à OFF, faz upsert e devolve)
  @Get('search-confirm')
  async searchConfirm(@Query() dto: SearchDto) {
    return this.products.searchConfirm(dto.q, dto.page, dto.pageSize);
  }

  // Histórico do utilizador — requer JWT
  // GET /products/history?from=YYYY-MM-DD&to=YYYY-MM-DD&page=1&pageSize=20
  @UseGuards(AccessTokenGuard)
  @Get('history')
  async history(
    @Req() req: any,
    @Query('page', ParseIntPipe) page = 1,
    @Query('pageSize', ParseIntPipe) pageSize = 20,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const userId: string = req.user.sub;
    return this.products.listHistory(userId, page, pageSize, from, to);
  }

  // Pesquisa híbrida (local + enrichment async)
  @Get()
  async search(@Query() q: SearchDto) {
    return this.products.searchHybrid(q.q, q.page, q.pageSize);
  }

  // ---- DINÂMICAS DEPOIS ----

  // Detalhe por barcode (requer JWT) → upsert + grava em ProductHistory
  @UseGuards(AccessTokenGuard)
  @Get(':barcode')
  async getByBarcode(@Param('barcode') barcode: string, @Req() req: any) {
    const userId: string = req.user.sub;
    return this.products.getByBarcode(barcode, userId);
  }

  // Favoritos (toggle) — requer JWT
  @UseGuards(AccessTokenGuard)
  @Post(':barcode/favorite')
  async toggleFavorite(@Param('barcode') barcode: string, @Req() req: any) {
    const userId: string = req.user.sub;
    // devolve 200 por omissão (Nest), o body indica o estado
    return this.products.toggleFavorite(userId, barcode);
  }
}
