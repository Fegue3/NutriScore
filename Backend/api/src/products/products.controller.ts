import { Controller, Get, Param, Query, Req, Post, UseGuards } from '@nestjs/common';
import { ProductsService } from './products.service';
import { SearchDto } from './dto/search.dto';
import { AccessTokenGuard } from '../auth/auth.guards';

@Controller('products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  // Sugestões rápidas (só cache local)
  @Get('suggest')
  async suggest(@Query('q') q: string, @Query('limit') limit = 8) {
    return this.products.suggestLocal(q, Number(limit));
  }

  // Pesquisa confirmada (vai à OFF, faz upsert e devolve)
  @Get('search-confirm')
  async searchConfirm(@Query() dto: SearchDto) {
    return this.products.searchConfirm(dto.q, dto.page, dto.pageSize);
  }

  // Pesquisa híbrida (local + enrichment async)
  @Get()
  async search(@Query() q: SearchDto) {
    return this.products.searchHybrid(q.q, q.page, q.pageSize);
  }

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
    return this.products.toggleFavorite(userId, barcode);
  }
}
