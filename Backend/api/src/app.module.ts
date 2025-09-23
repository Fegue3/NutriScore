import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { GoalsModule } from './goals/goals.module';
import {CaloriesModule} from "./calories/calories.module"

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    GoalsModule,
    CaloriesModule,
  ],
})
export class AppModule {}
