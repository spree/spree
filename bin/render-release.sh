#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_DIR="$ROOT/server"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "→ Skipping database preparation because DATABASE_URL is not set"
  exit 0
fi

cd "$SERVER_DIR"

export SPREE_PATH="$ROOT"

# Rails engines' migrations only become visible to db:migrate once copied
# into the host app's db/migrate — Spree's own "Missing migrations" warning
# names this exact task. server/ is freshly cloned every build (see
# bin/render-build.sh), so the copy has to happen on every release too,
# before db:prepare can apply anything new from spree/core.
echo "→ Copying engine migrations into the host app"
BUNDLE_IGNORE_CONFIG=1 bundle exec rake spree:install:migrations

echo "→ Preparing database"
BUNDLE_IGNORE_CONFIG=1 bundle exec rails db:prepare
BUNDLE_IGNORE_CONFIG=1 bundle exec rails db:migrate
BUNDLE_IGNORE_CONFIG=1 bundle exec rails spree:role_users:backfill_store_ids
