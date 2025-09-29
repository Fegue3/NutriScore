import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Query,
  Param,
  Req,
  UseGuards,
  BadRequestException,
  UnauthorizedException,
} from '@nestjs/common';
import { AccessTokenGuard } from '../auth/auth.guards';
import { MealsService } from './meals.service';
import { CreateMealsDto } from './meals.dto'; // <- era AddMealDto

@Controller('meals')
@UseGuards(AccessTokenGuard)
export class MealsController {
  constructor(private readonly meals: MealsService) {}

  @Get()
  async getDay(@Req() req: any, @Query('date') date?: string) {
    const user = req.user;
    if (!user) throw new UnauthorizedException('Missing user in request');
    const userId: string | undefined = user.id ?? user.sub;
    if (!userId) throw new UnauthorizedException('Invalid JWT payload');

    // service espera string, por isso damos fallback para "hoje"
    const ymd = date ?? new Date().toISOString().slice(0, 10);
    return this.meals.getDay(userId, ymd);
  }

  @Post()
  async add(@Req() req: any, @Body() dto: CreateMealsDto) {
    const user = req.user;
    if (!user) throw new UnauthorizedException('Missing user in request');
    const userId: string | undefined = user.id ?? user.sub;
    if (!userId) throw new UnauthorizedException('Invalid JWT payload');

    if (!dto?.type || !dto?.items?.length) {
      throw new BadRequestException('type and items are required');
    }
    return this.meals.add(userId, dto);
  }

  // DELETE /meals/:mealId/items/:itemId  -> usa o nome do service correcto
  @Delete(':mealId/items/:itemId')
  async deleteItem(
    @Param('mealId') mealId: string,
    @Param('itemId') itemId: string,
  ) {
    return this.meals.deleteMealItem(mealId, itemId);
  }

  // DELETE /meals/items/:itemId
  @Delete('items/:itemId')
  async deleteItemById(@Param('itemId') itemId: string) {
    return this.meals.deleteItemById(itemId);
  }
}
