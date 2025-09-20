import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get('health')
  health() {
    return {
      status: 'ok',
      message: 'API is running!',
      timestamp: new Date().toISOString(),
    };
  }
}
