// src/users/users.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, User } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findById(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async createUser(email: string, passwordHash: string, name?: string | null): Promise<User> {
    const user = await this.prisma.user.create({
      data: { email, passwordHash, name: name ?? null },
    });
    await this.prisma.userGoals.create({ data: { userId: user.id } }).catch(() => {});
    return user;
  }

  updateRefreshHash(userId: string, refreshTokenHash: string | null) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { refreshTokenHash },
    });
  }

  async deleteUserCascade(userId: string) {
    await this.prisma.user
      .update({ where: { id: userId }, data: { refreshTokenHash: null }, select: { id: true } })
      .catch(() => {});

    try {
      await this.prisma.user.delete({ where: { id: userId } });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
        // já não existe
      } else {
        throw err;
      }
    }
    return { ok: true };
  }

  // >>> Novo: update de campos básicos do utilizador
  updateUser(userId: string, data: { name?: string; email?: string }) {
    const payload: Prisma.UserUpdateInput = {};
    if (typeof data.name === 'string') payload.name = data.name;
    if (typeof data.email === 'string') payload.email = data.email;
    return this.prisma.user.update({ where: { id: userId }, data: payload });
  }

  // ---------------- Flags de onboarding ----------------
  async getFlags(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: { onboardingCompleted: true },
    });
  }

  async setFlags(userId: string, flags: { onboardingCompleted?: boolean }) {
    const data: Record<string, any> = {};
    if (typeof flags.onboardingCompleted === 'boolean') {
      data.onboardingCompleted = flags.onboardingCompleted;
    }
    if (Object.keys(data).length === 0) return { ok: true };
    await this.prisma.user.update({ where: { id: userId }, data });
    return { ok: true };
  }
}
