#!/bin/sh
set -eu

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

if command -v sudo >/dev/null 2>&1; then
  sudo usermod -aG docker "${USER}" || true
  sudo mkdir -p /opt/foundit
  sudo chown "${USER}:${USER}" /opt/foundit
else
  mkdir -p /opt/foundit
fi

echo "Docker 已就緒。請把 deploy/.env.example 放到 /opt/foundit/.env 並填入正式值，DNS 指到這台主機後再打開 GitHub 變數 DEPLOY_ENABLED。"
