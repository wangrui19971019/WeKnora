#!/usr/bin/env bash
# Cloud Agent setup for WeKnora.
#
# Builds the zero-external-dependency "Lite" edition (SQLite + FTS5/sqlite-vec
# retrieval, in-memory stream manager, local file storage, embedded frontend)
# so an agent can build, run, and test the full backend + Web UI without Docker
# or any external infrastructure. Idempotent: safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

echo ">> [1/4] Ensuring system dependencies (libsqlite3-dev for sqlite-vec CGO bindings)..."
if ! dpkg -s libsqlite3-dev >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends libsqlite3-dev
fi

echo ">> [2/4] Downloading Go modules..."
go mod download

echo ">> [3/4] Building Lite binary + frontend bundle (make build-lite)..."
# build-lite runs `npm ci --prefer-offline && npm run build` for the frontend,
# copies the bundle to ./web, then compiles ./WeKnora-lite with sqlite_fts5.
make build-lite

echo ">> [4/4] Preparing Lite runtime config (.env.lite) and data dirs..."
if [ ! -f .env.lite ]; then
  cp .env.lite.example .env.lite
  # SYSTEM_AES_KEY encrypts stored credentials; JWT_SECRET signs auth tokens.
  # Generated once and kept in the (git-ignored) .env.lite so they stay stable.
  aes_key="$(openssl rand -hex 16)"
  jwt_secret="$(openssl rand -hex 32)"
  sed -i "s|^SYSTEM_AES_KEY=.*|SYSTEM_AES_KEY=${aes_key}|" .env.lite
  sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${jwt_secret}|" .env.lite
  echo "   Wrote .env.lite with freshly generated SYSTEM_AES_KEY and JWT_SECRET."
else
  echo "   .env.lite already present; leaving it untouched."
fi
mkdir -p data data/files

echo ">> Setup complete. Start the server with: set -a && . ./.env.lite && set +a && ./WeKnora-lite"
