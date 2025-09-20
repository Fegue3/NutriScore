# --- build stage ---
FROM node:20-alpine AS builder
WORKDIR /app

# Prisma precisa disto no Alpine
RUN apk add --no-cache openssl libc6-compat

# 1) deps
COPY package*.json ./
RUN npm ci

# 2) prisma generate
COPY prisma ./prisma
RUN npx prisma generate

# 3) código e build
COPY tsconfig*.json nest-cli.json ./
COPY src ./src
RUN npm run build

# --- runtime stage ---
FROM node:20-alpine AS runner
WORKDIR /app

# Prisma runtime deps
RUN apk add --no-cache openssl libc6-compat

ENV NODE_ENV=production
EXPOSE 3000

# artefactos
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY prisma ./prisma

# entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# opcional: healthcheck
HEALTHCHECK --interval=10s --timeout=3s --retries=10 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["/entrypoint.sh"]
