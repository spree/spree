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
# resolution mismatch. Boot can print its own lines to stdout (Spree's
# missing-migration warnings on a fresh clone), so the name is fenced with a
# marker rather than taken as the whole output.
resolved=$(cd server && DATABASE_NAME="$TEMPLATE_DB" \
  bin/rails runner 'print "\n__RESOLVED__#{ActiveRecord::Base.connection_db_config.database}"') || {
  echo "Could not read the database configuration from server/ — see the error above." >&2
  exit 1
}
resolved="${resolved##*__RESOLVED__}"
if [ "$resolved" != "$TEMPLATE_DB" ]; then
  echo "Rails resolved the development database to '$resolved', not '$TEMPLATE_DB'." >&2
  echo "Refusing to rebuild — check server/config/database.yml and server/.env." >&2
  exit 1
fi

echo "▸ Rebuilding $TEMPLATE_DB (full migration run + seeds, ~4-5 min)"

# db:drop/db:create rather than dropdb/createdb: Rails connects using the config
# just verified, so the destructive step cannot reach a different host or port
# than the name check covered.
#
# db:migrate, not db:prepare. The starter commits a db/schema.rb, so db:prepare
# would load that snapshot into the empty database and then run only the
# migrations newer than its version — meaning the starter's own migrations never
# execute here, and the 6.0 migrations still living in the monorepo gems are the
# only ones actually exercised. Migrating from empty runs the whole set in order,
# so a migration that is broken, mis-ordered or depends on something an earlier
# one no longer creates fails while building the template rather than during
# somebody's upgrade.
#
# ADMIN_EMAIL/ADMIN_PASSWORD are required explicitly since 6.0 — the seed no
# longer ships dummy defaults. These are the documented worktree credentials.
(cd server && DATABASE_NAME="$TEMPLATE_DB" DATABASE_NAME_TEST="$TEMPLATE_DB" \
  ADMIN_EMAIL="spree@example.com" ADMIN_PASSWORD="spree123" \
  bin/rails db:drop db:create spree:install:migrations db:migrate db:seed)

echo "✓ $TEMPLATE_DB ready — new worktrees copy it via createdb -T"
