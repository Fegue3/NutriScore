import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { WeightController } from './weight.controller';
import { WeightService } from './weight.service';

@Module({
  imports: [PrismaModule],
  controllers: [WeightController],
  providers: [WeightService],
  exports: [WeightService],
})
export class WeightModule {}
