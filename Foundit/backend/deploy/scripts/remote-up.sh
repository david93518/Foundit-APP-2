#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if [ -z "${API_IMAGE:-}" ]; then
  echo "API_IMAGE 未設定" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo "找不到 .env。請先把 deploy/.env.example 抄成 .env 並填入正式值。" >&2
  exit 1
fi

umask 077
printf 'API_IMAGE=%s\n' "$API_IMAGE" > .deploy.env

cleanup() {
  docker logout ghcr.io >/dev/null 2>&1 || true
}
trap cleanup EXIT

set -a
# shellcheck disable=SC1091
. ./.deploy.env
set +a

docker compose pull api
docker compose up -d --remove-orphans
sh ./scripts/issue-certs.sh
docker compose exec -T nginx wget -qO- http://api:3000/api/v1/health
