import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards, Req } from '@nestjs/common';
import { AuthService } from './auth.service';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { AccessTokenGuard, RefreshTokenGuard } from './auth.guards';

class RegisterDto { @IsEmail() email!: string; @IsString() @MinLength(8) password!: string; @IsString() @IsOptional() name?: string; }
class LoginDto    { @IsEmail() email!: string; @IsString() password!: string; }
class RefreshDto  { @IsString() refreshToken!: string; }
class LogoutDto   { @IsString() userId!: string; }

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('register') register(@Body() dto: RegisterDto) { return this.auth.register(dto.email, dto.password, dto.name); }

  @Post('login') @HttpCode(HttpStatus.OK) login(@Body() dto: LoginDto) { return this.auth.login(dto.email, dto.password); }

  @UseGuards(RefreshTokenGuard)
  @Post('refresh') @HttpCode(HttpStatus.OK)
  refresh(@Req() req: any, @Body() _dto: RefreshDto) { return this.auth.rotateRefresh(req.user.sub, req.user.email, req.user.refreshToken); }

  @Post('logout') @HttpCode(HttpStatus.OK)
  async logout(@Body() dto: LogoutDto) { await this.auth.logout(dto.userId); return { ok: true }; }

  @UseGuards(AccessTokenGuard)
  @Get('me') me(@Req() req: any) { const u = req.user; return { user: { id: u.sub, email: u.email } }; }
}
