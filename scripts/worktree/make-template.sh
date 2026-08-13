#!/usr/bin/env bash
# Create (or refresh) the seeded template database that worktree databases are
# copied from. Run once after machine setup, and again after pulling
# schema-changing migrations. Takes ~2-3 minutes (migrations + Spree seeds);
# copying from it afterwards takes ~2 seconds.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "$(worktree_root)"

[ -d server ] || { echo "server/ missing — run pnpm server:create (or scripts/worktree/setup.sh) first." >&2; exit 1; }

require_current_starter

(cd server && bundle install --quiet)

# Prove Rails resolves DATABASE_NAME before dropping anything: this script
# rebuilds from scratch, so a config that ignored it would destroy the
# developer's own spree_development database. Needs the bundle above, and
# keeps stderr so a boot failure reports itself instead of looking like a
# resolution mismatch.
resolved=$(cd server && DATABASE_NAME="$TEMPLATE_DB" \
  bin/rails runner 'print ActiveRecord::Base.connection_db_config.database') || {
  echo "Could not read the database configuration from server/ — see the error above." >&2
  exit 1
}
if [ "$resolved" != "$TEMPLATE_DB" ]; then
  echo "Rails resolved the development database to '$resolved', not '$TEMPLATE_DB'." >&2
  echo "Refusing to rebuild — check server/config/database.yml and server/.env." >&2
  exit 1
fi

echo "▸ Rebuilding $TEMPLATE_DB (migrations + seeds, ~2-3 min)"

# db:drop/db:create rather than dropdb/createdb: Rails connects using the config
# just verified, so the destructive step cannot reach a different host or port
# than the name check covered.
# ADMIN_EMAIL/ADMIN_PASSWORD are required explicitly since 6.0 — the seed no
# longer ships dummy defaults. These are the documented worktree credentials.
(cd server && DATABASE_NAME="$TEMPLATE_DB" DATABASE_NAME_TEST="$TEMPLATE_DB" \
  ADMIN_EMAIL="spree@example.com" ADMIN_PASSWORD="spree123" \
  bin/rails db:drop db:create spree:install:migrations db:prepare)

echo "✓ $TEMPLATE_DB ready — new worktrees copy it via createdb -T"
