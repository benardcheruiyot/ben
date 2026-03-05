#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/html/kopa-mkopaji}"
APP_NAME="${APP_NAME:-kopa-mkopaji}"
DOMAIN="${DOMAIN:-kopa.mkopaji.com}"
WWW="${WWW:-www.kopa.mkopaji.com}"
EMAIL="${EMAIL:-admin@kopa.mkopaji.com}"
SITE_NAME="${SITE_NAME:-kopa-mkopaji}"

echo "==> Starting force deployment"
echo "APP_DIR=${APP_DIR}"

cd "${APP_DIR}"

echo "==> Pulling latest code"
git fetch origin main
git reset --hard origin/main

echo "==> Installing production dependencies"
npm ci --only=production

if [[ -f .env.production ]]; then
  cp .env.production .env
  echo "==> Loaded .env from .env.production"
fi

echo "==> Repairing nginx/TLS/API routing"
SITE_NAME="${SITE_NAME}" DOMAIN="${DOMAIN}" WWW="${WWW}" EMAIL="${EMAIL}" bash tools/fix_mkopaji_www_tls_noninteractive.sh

echo "==> Restarting app with PM2"
if pm2 describe "${APP_NAME}" >/dev/null 2>&1; then
  pm2 restart "${APP_NAME}" --update-env
else
  pm2 start ecosystem.config.js --env production --name "${APP_NAME}" --update-env
fi
pm2 save

echo "==> Validating nginx"
nginx -t
systemctl reload nginx

echo "==> Health check"
curl -fsS "http://localhost:3002/api/health" >/dev/null

echo "==> API route check"
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://${DOMAIN}/api/initiate-stk-push" -H "Content-Type: application/json" -d '{"phoneNumber":"254700000000","amount":1,"accountReference":"DEPLOY-CHECK"}' || true)
echo "POST /api/initiate-stk-push => ${API_STATUS}"
if [[ "${API_STATUS}" == "404" || "${API_STATUS}" == "405" ]]; then
  echo "ERROR: API routing still broken after deploy (status ${API_STATUS})" >&2
  exit 1
fi

echo "✅ Force deployment complete"