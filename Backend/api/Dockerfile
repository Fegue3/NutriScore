# --- build stage ---
FROM node:20-alpine AS builder
WORKDIR /app

# Prisma precisa disto no Alpine
RUN apk add --no-cache openssl libc6-compat

# 1) instalar deps (inclui dev deps por omissão)
COPY package*.json ./
RUN npm ci

# 2) gerar o client Prisma (precisa do schema presente)
COPY prisma ./prisma
RUN npx prisma generate

# 3) copiar configs e código e buildar
COPY tsconfig*.json nest-cli.json ./
COPY src ./src
RUN npm run build

# --- runtime stage ---
FROM node:20-alpine AS runner
WORKDIR /app

# Prisma precisa disto também em runtime
RUN apk add --no-cache openssl libc6-compat

ENV NODE_ENV=production

# copiar artefactos do builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY prisma ./prisma

# entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000
CMD ["/entrypoint.sh"]
