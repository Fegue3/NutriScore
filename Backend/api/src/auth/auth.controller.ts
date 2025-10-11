import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards, Req, Delete } from '@nestjs/common';
import { AuthService } from './auth.service';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { AccessTokenGuard, RefreshTokenGuard } from './auth.guards';
import { UsersService } from '../users/users.service';

class RegisterDto { @IsEmail() email!: string; @IsString() @MinLength(8) password!: string; @IsString() @IsOptional() name?: string; }
class LoginDto    { @IsEmail() email!: string; @IsString() password!: string; }
class RefreshDto  { @IsString() refreshToken!: string; }
class LogoutDto   { @IsString() userId!: string; }

@Controller('auth')
export class AuthController {
  constructor(
    private auth: AuthService,
    private users: UsersService,
  ) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto.email, dto.password, dto.name);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @UseGuards(RefreshTokenGuard)
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Req() req: any, @Body() _dto: RefreshDto) {
    return this.auth.rotateRefresh(req.user.sub, req.user.email, req.user.refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  async logout(@Body() dto: LogoutDto) {
    await this.auth.logout(dto.userId);
    return { ok: true };
  }

  @UseGuards(AccessTokenGuard)
  @Get('me')
  async me(@Req() req: any) {
    const u = req.user;
    const dbUser = await this.users.findById(u.sub);
    return {
      user: {
        id: u.sub,
        email: u.email,
        name: dbUser?.name ?? null,
        onboardingCompleted: !!dbUser?.onboardingCompleted,
      },
    };
  }

  @UseGuards(AccessTokenGuard)
  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteMe(@Req() req: any) {
    const userId = req.user.sub as string;
    try {
      await this.auth.deleteSelf(userId);
    } catch {
      // idempotente
    }
    return;
  }
}
