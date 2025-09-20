# --- build stage ---
FROM node:20-alpine AS builder
WORKDIR /app

# deps nativas
RUN apk add --no-cache openssl libc6-compat

# 0) Prisma precisa disto no build (NUNCA vazio)
ARG DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy?schema=public"
ENV DATABASE_URL=$DATABASE_URL

# 1) deps (inclui devDeps porque compilas no build)
COPY package*.json ./
RUN npm ci --include=dev

# 2) prisma client
COPY prisma ./prisma
# (o teu schema já tem: url = env("DATABASE_URL"))
RUN npx prisma generate

# 3) código + build
COPY tsconfig*.json nest-cli.json ./
COPY src ./src

# usa o teu script "build": "nest build"
RUN npm run build

# --- runtime stage ---
FROM node:20-alpine AS runner
WORKDIR /app

RUN apk add --no-cache openssl libc6-compat
ENV NODE_ENV=production
EXPOSE 3000

# artefactos
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY prisma ./prisma

# arranca a API diretamente
CMD ["node", "dist/main.js"]
