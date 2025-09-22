import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import * as argon2 from 'argon2';
import { JwtService, type JwtSignOptions } from '@nestjs/jwt';

type Tokens = { accessToken: string; refreshToken: string };

function mustEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

@Injectable()
export class AuthService {
  private readonly accessSecret = mustEnv('JWT_ACCESS_SECRET');
  private readonly refreshSecret = mustEnv('JWT_REFRESH_SECRET');
  private readonly accessTtl = process.env.ACCESS_TOKEN_TTL ?? '15m';
  private readonly refreshTtl = process.env.REFRESH_TOKEN_TTL ?? '30d';

  constructor(private users: UsersService, private jwt: JwtService) {}

  private signAccess(user: { id: string; email: string }) {
    const payload = { sub: user.id, email: user.email, typ: 'access' } as const;
    const opts: JwtSignOptions = { secret: this.accessSecret, expiresIn: this.accessTtl };
    return this.jwt.sign(payload, opts);
  }

  private signRefresh(user: { id: string; email: string }) {
    const payload = { sub: user.id, email: user.email, typ: 'refresh' } as const;
    const opts: JwtSignOptions = { secret: this.refreshSecret, expiresIn: this.refreshTtl };
    return this.jwt.sign(payload, opts);
  }

  private async issueTokensAndPersist(userId: string, email: string): Promise<Tokens> {
    const accessToken = this.signAccess({ id: userId, email });
    const refreshToken = this.signRefresh({ id: userId, email });
    const refreshTokenHash = await argon2.hash(refreshToken, { type: argon2.argon2id });
    await this.users.updateRefreshHash(userId, refreshTokenHash);
    return { accessToken, refreshToken };
  }

  async register(email: string, password: string, name?: string) {
    const exists = await this.users.findByEmail(email);
    if (exists) throw new ConflictException('Email já registado');
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
    const user = await this.users.createUser(email, passwordHash, name);
    const tokens = await this.issueTokensAndPersist(user.id, user.email);
    return { user: { id: user.id, email: user.email, name: user.name }, tokens };
  }

  async login(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user) throw new UnauthorizedException('Credenciais inválidas');
    const ok = await argon2.verify(user.passwordHash, password);
    if (!ok) throw new UnauthorizedException('Credenciais inválidas');
    const tokens = await this.issueTokensAndPersist(user.id, user.email);
    return { user: { id: user.id, email: user.email, name: user.name }, tokens };
  }

  async rotateRefresh(userId: string, email: string, refreshTokenRaw: string) {
    const user = await this.users.findById(userId);
    if (!user || !user.refreshTokenHash) throw new UnauthorizedException('Refresh rejeitado');
    const valid = await (await import('argon2')).default.verify(user.refreshTokenHash, refreshTokenRaw);
    if (!valid) {
      await this.users.updateRefreshHash(userId, null);
      throw new UnauthorizedException('Refresh inválido');
    }
    return { tokens: await this.issueTokensAndPersist(userId, email) };
  }

  async logout(userId: string) {
    await this.users.updateRefreshHash(userId, null).catch(() => {});
  }

  /**
   * Apaga a própria conta, revoga refresh tokens e deixa o access token expirar naturalmente.
   */
  async deleteSelf(userId: string) {
    await this.users.deleteUserCascade(userId);
    return { ok: true };
  }
}
