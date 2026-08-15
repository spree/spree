#!/usr/bin/env bash
# Provision the current worktree as a self-contained dev environment:
# its own server/ clone, .env, database (copied from the seeded template),
# gems, node modules, and dashboard proxy config. Idempotent — safe to re-run.
# Usage: setup.sh [branch]   (branch defaults to the current one; worktrunk
# passes it explicitly from the pre-start hook)
set -euo pipefail
WT_BRANCH="${1:-}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "$(worktree_root)"

echo "▸ Provisioning worktree '$(branch_slug)' (db: $(db_name))"

if [ ! -d server ]; then
  echo "▸ Cloning spree-starter into server/"
  git clone --depth 1 --branch 6-0-dev https://github.com/spree/spree-starter.git server
  rm -rf server/.git server/.gitignore
fi

if [ ! -f server/.env ]; then
  cat > server/.env <<EOF
SPREE_PATH=$(pwd)
SECRET_KEY_BASE=$(openssl rand -hex 64)
DATABASE_NAME=$(db_name)
DATABASE_NAME_TEST=$(test_db_name)
SPREE_DASHBOARD_URL=$(dashboard_url)
RAILS_HOST=$(rails_host)
EOF
fi

# Backfill for worktrees provisioned before this line existed — the seed's
# first-run setup link is built from it.
if ! grep -q '^SPREE_DASHBOARD_URL=' server/.env; then
  printf 'SPREE_DASHBOARD_URL=%s\n' "$(dashboard_url)" >> server/.env
fi

# Backfill likewise: without it, attachment URLs in API payloads fall back to
# the store's seeded `localhost:3000`, so dashboard images 404.
if ! grep -q '^RAILS_HOST=' server/.env; then
  printf 'RAILS_HOST=%s\n' "$(rails_host)" >> server/.env
fi

require_current_starter

if ! db_exists "$(db_name)"; then
  if ! db_exists "$TEMPLATE_DB"; then
    echo "Template database '$TEMPLATE_DB' missing — run scripts/worktree/make-template.sh first." >&2
    exit 1
  fi
  echo "▸ Creating $(db_name) from $TEMPLATE_DB"
  createdb "${PG_ARGS[@]}" -T "$TEMPLATE_DB" "$(db_name)"
fi

# Warm boot caches from the primary checkout's server, if it has any.
primary_root=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
if [ -d "$primary_root/server/tmp/cache/bootsnap" ] && [ ! -d server/tmp/cache/bootsnap ]; then
  mkdir -p server/tmp/cache
  cp -R "$primary_root/server/tmp/cache/bootsnap" server/tmp/cache/
fi

echo "▸ Installing gems + migrations"
(cd server && bundle install --quiet && bin/rails spree:install:migrations db:migrate)

echo "▸ Installing node modules"
pnpm install --silent

mkdir -p packages/dashboard-starter
printf 'VITE_API_PROXY_TARGET=%s\n' "$(rails_url)" > packages/dashboard-starter/.env.local

echo "✓ Worktree ready"
echo "  rails:     $(rails_url)   (pnpm wt:dev)"
echo "  dashboard: $(dashboard_url)   (pnpm wt:dashboard)"
