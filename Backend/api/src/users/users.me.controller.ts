import { Body, Controller, Get, HttpCode, HttpStatus, Patch, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/auth.guards';
import { UsersService } from './users.service';
import { IsBoolean, IsOptional } from 'class-validator';

class FlagsDto {
  @IsOptional()
  @IsBoolean()
  onboardingCompleted?: boolean;
}

@UseGuards(AccessTokenGuard)
@Controller('api/me')
export class UsersMeController {
  constructor(private users: UsersService) {}

  @Get('flags')
  async getFlags(@Req() req: any) {
    const userId = req.user.sub as string;
    const flags = await this.users.getFlags(userId);
    return { flags };
  }

  @Patch('flags')
  @HttpCode(HttpStatus.OK)
  async setFlags(@Req() req: any, @Body() dto: FlagsDto) {
    const userId = req.user.sub as string;
    return this.users.setFlags(userId, { onboardingCompleted: dto.onboardingCompleted });
  }
}
