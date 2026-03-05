#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="${LOCK_FILE:-/var/lock/kopa-mkopaji-deploy.lock}"
APP_DIR="${APP_DIR:-/var/www/html/kopa-mkopaji}"
APP_NAME="${APP_NAME:-kopa-mkopaji}"
DOMAIN="${DOMAIN:-kopa.mkopaji.com}"
WWW="${WWW:-www.kopa.mkopaji.com}"
EMAIL="${EMAIL:-admin@kopa.mkopaji.com}"
SITE_NAME="${SITE_NAME:-kopa-mkopaji}"
BRANCH="${BRANCH:-main}"

mkdir -p "$(dirname "${LOCK_FILE}")"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "Another deploy run is in progress. Exiting."
  exit 0
fi

cd "${APP_DIR}"

echo "Checking for updates on origin/${BRANCH}..."
git fetch origin "${BRANCH}" --quiet

LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "origin/${BRANCH}")"

if [[ "${LOCAL_SHA}" == "${REMOTE_SHA}" ]]; then
  echo "No new commits. Nothing to deploy."
  exit 0
fi

echo "New commit detected: ${LOCAL_SHA} -> ${REMOTE_SHA}"
echo "Running force deploy workflow..."

chmod +x tools/force-server-deploy.sh
APP_DIR="${APP_DIR}" \
APP_NAME="${APP_NAME}" \
DOMAIN="${DOMAIN}" \
WWW="${WWW}" \
EMAIL="${EMAIL}" \
SITE_NAME="${SITE_NAME}" \
bash tools/force-server-deploy.sh

echo "Auto-recover deployment completed."