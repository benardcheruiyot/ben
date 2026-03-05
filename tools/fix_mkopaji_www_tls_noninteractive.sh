#!/usr/bin/env bash
# Non-interactive script to fix www -> apex redirect, obtain SAN certs, and reload nginx
# Intended to be run on the server as root (e.g., via SSH action)
set -euo pipefail

DOMAIN="${DOMAIN:-kopa.mkopaji.com}"
WWW="${WWW:-www.kopa.mkopaji.com}"
EMAIL="${EMAIL:-admin@kopa.mkopaji.com}"
SITE_CONF="/etc/nginx/sites-available/mkopaji.conf"
SITE_LINK="/etc/nginx/sites-enabled/mkopaji.conf"
BACKUP_DIR="/root/nginx-backups-$(date +%Y%m%d-%H%M%S)"
WEBROOT="/var/www/html/kopa-mkopaji/frontend"

restore_backup_and_exit() {
  echo "nginx config test failed. Restoring backups and exiting." >&2
  cp "${BACKUP_DIR}/nginx.conf.bak" /etc/nginx/nginx.conf 2>/dev/null || true
  cp -r "${BACKUP_DIR}/sites-available.bak/." /etc/nginx/sites-available/ 2>/dev/null || true
  cp -r "${BACKUP_DIR}/sites-enabled.bak/." /etc/nginx/sites-enabled/ 2>/dev/null || true
  exit "$1"
}

domain_resolves() {
  local name="$1"
  if command -v getent >/dev/null 2>&1; then
    getent hosts "$name" >/dev/null 2>&1 && return 0
  fi
  if command -v host >/dev/null 2>&1; then
    host "$name" >/dev/null 2>&1 && return 0
  fi
  if command -v nslookup >/dev/null 2>&1; then
    nslookup "$name" >/dev/null 2>&1 && return 0
  fi
  return 1
}

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Exiting." >&2
  exit 2
fi

echo "Backing up nginx configs to ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
cp /etc/nginx/nginx.conf "${BACKUP_DIR}/nginx.conf.bak" 2>/dev/null || true
cp -r /etc/nginx/sites-available "${BACKUP_DIR}/sites-available.bak" 2>/dev/null || true
cp -r /etc/nginx/sites-enabled "${BACKUP_DIR}/sites-enabled.bak" 2>/dev/null || true

mkdir -p "${WEBROOT}" "${WEBROOT}/.well-known/acme-challenge"

HAS_WWW=0
if domain_resolves "${WWW}"; then
  HAS_WWW=1
  echo "WWW domain resolves and will be included in certificate: ${WWW}"
else
  echo "WWW domain does not resolve yet: ${WWW}. Proceeding with apex cert only."
fi

SERVER_NAMES="${DOMAIN}"
if [[ ${HAS_WWW} -eq 1 ]]; then
  SERVER_NAMES="${SERVER_NAMES} ${WWW}"
fi

CERTBOT_DOMAINS_ARGS=( -d "${DOMAIN}" )
if [[ ${HAS_WWW} -eq 1 ]]; then
  CERTBOT_DOMAINS_ARGS+=( -d "${WWW}" )
fi

# Install certbot if missing (apt-based systems)
if ! command -v certbot >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
  else
    echo "certbot not installed and apt-get not found. Install certbot manually." >&2
    exit 4
  fi
fi

# 1) Bootstrap HTTP-only config first so nginx can start before cert exists
cat > "${SITE_CONF}.new" <<NGINX_BOOTSTRAP
# mkopaji bootstrap config - HTTP only for ACME validation
server {
  listen 80;
  server_name ${SERVER_NAMES};

  root ${WEBROOT};
  index index.html index.htm;

  location /.well-known/acme-challenge/ {
    allow all;
  }

  location / {
    try_files \$uri \$uri/ =404;
  }
}
NGINX_BOOTSTRAP

mv "${SITE_CONF}.new" "${SITE_CONF}"
ln -sf "${SITE_CONF}" "${SITE_LINK}"

if ! nginx -t; then
  restore_backup_and_exit 3
fi

systemctl reload nginx || true

# 2) Obtain/renew certificate
set +e
certbot certonly --webroot -w "${WEBROOT}" --non-interactive --agree-tos --email "${EMAIL}" --keep-until-expiring "${CERTBOT_DOMAINS_ARGS[@]}"
CERTBOT_EXIT=$?
set -e

if [[ ${CERTBOT_EXIT} -ne 0 ]]; then
  echo "certbot --webroot failed; attempting standalone issuance"
  systemctl stop nginx || true
  certbot certonly --standalone --non-interactive --agree-tos --email "${EMAIL}" --keep-until-expiring "${CERTBOT_DOMAINS_ARGS[@]}"
  CERTBOT_EXIT=$?
  systemctl start nginx || true
  if [[ ${CERTBOT_EXIT} -ne 0 ]]; then
    echo "certbot failed. Check certbot logs on the server." >&2
    exit 5
  fi
fi

if [[ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" || ! -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]]; then
  echo "Expected cert files missing for ${DOMAIN}. Aborting." >&2
  exit 6
fi

# 3) Write final HTTPS config
cat > "${SITE_CONF}.new" <<NGINX_CONF
# mkopaji site config - created by automation
server {
  listen 80;
  server_name ${SERVER_NAMES};
  return 301 https://${DOMAIN}\$request_uri;
}

server {
  listen 443 ssl;
  server_name ${DOMAIN};

  root ${WEBROOT};
  index index.html index.htm;

  ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  location / {
    try_files \$uri \$uri.html \$uri/ /index.html;
  }
}
NGINX_CONF

if [[ ${HAS_WWW} -eq 1 ]]; then
  cat >> "${SITE_CONF}.new" <<NGINX_WWW

# Ensure www HTTPS redirects to apex
server {
  listen 443 ssl;
  server_name ${WWW};

  ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  return 301 https://${DOMAIN}\$request_uri;
}
NGINX_WWW
fi

mv "${SITE_CONF}.new" "${SITE_CONF}"
ln -sf "${SITE_CONF}" "${SITE_LINK}"

if ! nginx -t; then
  restore_backup_and_exit 7
fi

systemctl reload nginx || true

echo "Verification: headers for main endpoints"
curl -I --max-time 10 http://${DOMAIN} || true
curl -I --max-time 10 https://${DOMAIN} || true
if [[ ${HAS_WWW} -eq 1 ]]; then
  curl -I --max-time 10 http://${WWW} || true
  curl -I --max-time 10 https://${WWW} || true
fi

echo "Script complete. Backups stored in ${BACKUP_DIR}."
