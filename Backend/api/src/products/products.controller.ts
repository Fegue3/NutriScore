// src/products/products.controller.ts
import {
  Controller,
  Get,
  Param,
  Query,
  Req,
  Post,
  UseGuards,
  ParseIntPipe,
  Put,
  Delete,
} from '@nestjs/common';
import { ProductsService } from './products.service';
import { SearchDto } from './dto/search.dto';
import { FavoritesQueryDto } from './dto/favorites.dto';
import { AccessTokenGuard } from '../auth/auth.guards';

@Controller('products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  // ---- ESTÁTICAS PRIMEIRO (evita colidir com :barcode) ----

  // Sugestões rápidas (só cache local)
  @Get('suggest')
  async suggest(
    @Query('q') q: string,
    @Query('limit', ParseIntPipe) limit = 8,
  ) {
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

  // ======== FAVORITOS ========

  // Lista favoritos do utilizador (com dados do produto)
  // GET /products/favorites?q=...&page=1&pageSize=20
  @UseGuards(AccessTokenGuard)
  @Get('favorites')
  async listFavorites(@Req() req: any, @Query() q: FavoritesQueryDto) {
    const userId: string = req.user.sub;
    return this.products.listFavorites(userId, q.page, q.pageSize, q.q);
  }

  // Estado de favorito para um barcode
  // GET /products/:barcode/favorite
  @UseGuards(AccessTokenGuard)
  @Get(':barcode/favorite')
  async favoriteStatus(@Param('barcode') barcode: string, @Req() req: any) {
    const userId: string = req.user.sub;
    return this.products.isFavorited(userId, barcode);
  }

  // Add idempotente (garante favoritado=true)
  // PUT /products/:barcode/favorite
  @UseGuards(AccessTokenGuard)
  @Put(':barcode/favorite')
  async addFavorite(@Param('barcode') barcode: string, @Req() req: any) {
    const userId: string = req.user.sub;
    return this.products.addFavorite(userId, barcode);
  }

  // Remove idempotente (garante favoritado=false)
  // DELETE /products/:barcode/favorite
  @UseGuards(AccessTokenGuard)
  @Delete(':barcode/favorite')
  async removeFavorite(@Param('barcode') barcode: string, @Req() req: any) {
    const userId: string = req.user.sub;
    return this.products.removeFavorite(userId, barcode);
  }

  // Toggle (mantido para retrocompatibilidade)
  // POST /products/:barcode/favorite
  @UseGuards(AccessTokenGuard)
  @Post(':barcode/favorite')
  async toggleFavorite(@Param('barcode') barcode: string, @Req() req: any) {
    const userId: string = req.user.sub;
    return this.products.toggleFavorite(userId, barcode);
  }

  // ===========================

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
}
