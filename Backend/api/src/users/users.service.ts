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

  /**
   * Cria utilizador e o registo "goals" default (preferências integradas).
   */
  async createUser(
    email: string,
    passwordHash: string,
    name?: string | null,
  ): Promise<User> {
    const user = await this.prisma.user.create({
      data: { email, passwordHash, name: name ?? null },
    });

    // Criar UserGoals vazio (falha silenciosa se já existir)
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
    // Opcional: limpar refresh hash antes (não é estritamente necessário, mas é “higiénico”)
    await this.prisma.user
      .update({
        where: { id: userId },
        data: { refreshTokenHash: null },
        select: { id: true },
      })
      .catch(() => {});

    try {
      // Delete principal (respeita onDelete: Cascade definido no schema.prisma)
      await this.prisma.user.delete({ where: { id: userId } });
    } catch (err) {
      // Se o registo não existir (P2025), tratamos como idempotente.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2025'
      ) {
        // ignore
      } else {
        throw err;
      }
    }

    return { ok: true };
  }
}
