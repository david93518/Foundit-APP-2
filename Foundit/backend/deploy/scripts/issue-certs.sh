#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "找不到 .env。請先把 deploy/.env.example 抄成 .env 並填入正式值。" >&2
  exit 1
fi

if [ -f .deploy.env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.deploy.env
  set +a
fi

docker compose run --rm --entrypoint sh certbot -c '
set -eu
if [ -z "${LETSENCRYPT_EMAIL:-}" ]; then
  echo "LETSENCRYPT_EMAIL 未設定" >&2
  exit 1
fi
if [ -f /etc/letsencrypt/renewal/foundit.tw.conf ]; then
  certbot renew --webroot -w /var/www/certbot --deploy-hook "touch /var/www/certbot/reload-nginx"
  exit 0
fi
rm -rf /etc/letsencrypt/live/foundit.tw /etc/letsencrypt/archive/foundit.tw
certbot certonly --webroot -w /var/www/certbot \
  --cert-name foundit.tw \
  --non-interactive --agree-tos --no-eff-email \
  --email "$LETSENCRYPT_EMAIL" \
  -d foundit.tw -d www.foundit.tw -d api.foundit.tw \
  --deploy-hook "touch /var/www/certbot/reload-nginx"
'

docker compose exec -T nginx sh -c 'touch /var/www/certbot/reload-nginx; nginx -s reload'
