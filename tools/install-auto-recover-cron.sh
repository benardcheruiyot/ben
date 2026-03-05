#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/html/kopa-mkopaji}"
APP_NAME="${APP_NAME:-kopa-mkopaji}"
DOMAIN="${DOMAIN:-kopa.mkopaji.com}"
WWW="${WWW:-www.kopa.mkopaji.com}"
EMAIL="${EMAIL:-admin@kopa.mkopaji.com}"
SITE_NAME="${SITE_NAME:-kopa-mkopaji}"
BRANCH="${BRANCH:-main}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash tools/install-auto-recover-cron.sh"
  exit 1
fi

cd "${APP_DIR}"
chmod +x tools/force-server-deploy.sh tools/auto-recover-deploy.sh

CRON_CMD="cd ${APP_DIR} && APP_DIR=${APP_DIR} APP_NAME=${APP_NAME} DOMAIN=${DOMAIN} WWW=${WWW} EMAIL=${EMAIL} SITE_NAME=${SITE_NAME} BRANCH=${BRANCH} bash tools/auto-recover-deploy.sh >> /var/log/kopa-mkopaji-auto-deploy.log 2>&1"
CRON_LINE="*/5 * * * * ${CRON_CMD}"

TMP_CRON="$(mktemp)"
crontab -l 2>/dev/null | grep -v 'tools/auto-recover-deploy.sh' > "${TMP_CRON}" || true
echo "${CRON_LINE}" >> "${TMP_CRON}"
crontab "${TMP_CRON}"
rm -f "${TMP_CRON}"

echo "✅ Installed auto-recover cron job (every 5 minutes)."
echo "Log file: /var/log/kopa-mkopaji-auto-deploy.log"