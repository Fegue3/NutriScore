import { Controller, Get, UseGuards, Req } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/auth.guards';

@Controller('users')
export class UsersController {
  @UseGuards(AccessTokenGuard)
  @Get('me')
  me(@Req() req: any) {
    const user = req.user;
    return { user: { id: user.sub, email: user.email } };
  }
}
