#!/bin/sh
set -e
echo "DB up? vou gerar Prisma e migrar..."
npx prisma generate
npx prisma migrate dev
exec npm run start:dev
