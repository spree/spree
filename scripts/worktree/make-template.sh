#!/usr/bin/env bash
# Create (or refresh) the seeded template database that worktree databases are
# copied from. Run once after machine setup, and again after pulling
# schema-changing migrations. Takes ~2-3 minutes (migrations + Spree seeds);
# copying from it afterwards takes ~2 seconds.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "$(worktree_root)"

[ -d server ] || { echo "server/ missing — run pnpm server:create (or scripts/worktree/setup.sh) first." >&2; exit 1; }

if ! grep -q 'DATABASE_NAME' server/config/database.yml; then
  sed -i '' \
    -e 's|database: spree_development|database: <%= ENV.fetch("DATABASE_NAME") { "spree_development" } %>|' \
    -e 's|database: spree_test|database: <%= ENV.fetch("DATABASE_NAME_TEST") { "spree_test" } %>|' \
    server/config/database.yml
fi

echo "▸ Rebuilding $TEMPLATE_DB (migrations + seeds, ~2-3 min)"
dropdb "${PG_ARGS[@]}" --if-exists "$TEMPLATE_DB"
createdb "${PG_ARGS[@]}" "$TEMPLATE_DB"

(cd server && bundle install --quiet && \
  DATABASE_NAME="$TEMPLATE_DB" DATABASE_NAME_TEST="$TEMPLATE_DB" \
  bin/rails spree:install:migrations db:prepare)

echo "✓ $TEMPLATE_DB ready — new worktrees copy it via createdb -T"
