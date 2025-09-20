#!/bin/sh
set -e

echo "Esperando pelo DB..."
sleep 3

echo "Aplicando migrations..."
npx prisma migrate deploy

echo "Iniciando API..."
node dist/main.js
