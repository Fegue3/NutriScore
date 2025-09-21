import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { User } from '@prisma/client';

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

    // Criar o registo "goals" (que agora inclui as preferências)
    await this.prisma.userGoals.create({ data: { userId: user.id } }).catch(() => {});

    return user;
  }

  updateRefreshHash(userId: string, refreshTokenHash: string | null) {
    return this.prisma.user.update({ where: { id: userId }, data: { refreshTokenHash } });
  }
}
