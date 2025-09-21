import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy, StrategyOptions, StrategyOptionsWithRequest } from 'passport-jwt';
import type { Request } from 'express';

type JwtPayload = { sub: string; email: string; typ: 'access' | 'refresh' };

@Injectable()
export class JwtAccessStrategy extends PassportStrategy(Strategy, 'jwt-access') {
  constructor() {
    const opts: StrategyOptions = {
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_ACCESS_SECRET!,   // garantido por env
      ignoreExpiration: false,
    };
    super(opts);
  }
  validate(payload: JwtPayload) {
    if (payload.typ !== 'access') throw new Error('Invalid token type');
    return payload;
  }
}

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor() {
    const opts: StrategyOptionsWithRequest = {
      jwtFromRequest: ExtractJwt.fromBodyField('refreshToken'),
      secretOrKey: process.env.JWT_REFRESH_SECRET!, // garantido por env
      ignoreExpiration: false,
      passReqToCallback: true,
    };
    super(opts);
  }
  validate(req: Request, payload: JwtPayload) {
    if (payload.typ !== 'refresh') throw new Error('Invalid token type');
    const refreshToken = (req.body as any)?.refreshToken;
    return { ...payload, refreshToken };
  }
}
