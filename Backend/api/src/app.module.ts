import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { GoalsModule } from './goals/goals.module';
import {CaloriesModule} from "./calories/calories.module"
import { ProductsModule } from './products/products.module';
import { MealsModule } from './meals/meals.module';
import { StatsModule } from './stats/stats.module';
import {WeightModule} from "./weight/weight.module"

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    GoalsModule,
    CaloriesModule,
    ProductsModule,
    MealsModule,
    StatsModule,
    WeightModule,
  ],
})
export class AppModule {}
