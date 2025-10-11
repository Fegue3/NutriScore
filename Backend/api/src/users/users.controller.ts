// src/users/users.controller.ts
import { Body, Controller, Get, Patch, UseGuards, Req, HttpCode, HttpStatus, ConflictException } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/auth.guards';
import { UsersService } from './users.service';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

class UpdateUserDto {
  @IsOptional() @IsString() @MinLength(1)
  name?: string;

  // Se quiseres permitir mudar email (opcional):
  @IsOptional() @IsEmail()
  email?: string;
}

@UseGuards(AccessTokenGuard)
@Controller('users')
export class UsersController {
  constructor(private users: UsersService) {}

  @Get('me')
  async me(@Req() req: any) {
    const userId = req.user.sub as string;
    const u = await this.users.findById(userId);
    return { user: { id: u?.id, email: u?.email, name: u?.name ?? null } };
  }

  @Patch('me')
  @HttpCode(HttpStatus.OK)
  async updateMe(@Req() req: any, @Body() dto: UpdateUserDto) {
    const userId = req.user.sub as string;
    try {
      const updated = await this.users.updateUser(userId, dto);
      return { user: { id: updated.id, email: updated.email, name: updated.name ?? null } };
    } catch (e: any) {
      if (e?.code === 'P2002') throw new ConflictException('Email já em uso');
      throw e;
    }
  }
}
