import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';

describe('AppController', () => {
  it('health', () => {
    const c = new AppController();
    expect(c.health()).toEqual({ ok: true });
  });
});
