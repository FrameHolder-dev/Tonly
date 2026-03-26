#!/bin/bash
set -e

REPO_DIR="/opt/tonly"
BACKEND_DIR="$REPO_DIR/backend"

ufw allow 41922/tcp
ufw reload

cd "$REPO_DIR"
git fetch origin main
git reset --hard origin/main

cd "$BACKEND_DIR"
docker compose build --no-cache
docker compose up -d

docker image prune -f
