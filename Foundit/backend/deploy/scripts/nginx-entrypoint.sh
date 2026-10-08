#!/bin/sh
set -eu

nginx -g 'daemon off;' &
nginx_pid=$!

trap 'kill "$nginx_pid"' TERM INT

while kill -0 "$nginx_pid" 2>/dev/null; do
  if [ -f /var/www/certbot/reload-nginx ]; then
    rm -f /var/www/certbot/reload-nginx
    nginx -s reload || true
  fi
  sleep 30 &
  wait $! || true
done

wait "$nginx_pid"
