#!/usr/bin/env bash
# storefront-dev.sh — run the Next.js storefront against the Docker backend
# (`pnpm server:setup` / `pnpm server:dev`). The Docker twin of the worktree
# flow's `pnpm wt:storefront`.
#
# The storefront is a separate repo (spree/storefront, branch 6-0-dev) cloned
# into storefront/ on first run. Unlike server/, the clone keeps its .git —
# commit and push storefront work from inside it. It is deliberately not a
# member of this pnpm workspace (one lockfile cannot serve Next and the
# dashboard's Vite tree at once); it points @spree/sdk at packages/sdk through
# its own .pnpmfile.cjs whenever SPREE_SDK_PATH is set.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEV_COMPOSE="server/docker-compose.dev.yml"
EDGE_OVERLAY="scripts/docker-compose.edge.yml"
STOREFRONT_REPO="https://github.com/spree/storefront.git"
STOREFRONT_BRANCH="6-0-dev"
STOREFRONT_PORT="${STOREFRONT_PORT:-3001}"
API_URL="http://localhost:3000"

step() { printf '\n→ %s\n' "$1"; }

# The publishable key lives in the backend's database, so the stack must be up.
if [ ! -f "$DEV_COMPOSE" ] || [ -z "$(SPREE_PATH="$ROOT" docker compose -f "$DEV_COMPOSE" -f "$EDGE_OVERLAY" ps -q web 2>/dev/null)" ]; then
  echo "The backend is not running — pnpm server:setup (once), then pnpm server:dev." >&2
  exit 1
fi

if [ ! -d storefront ]; then
  step "Cloning spree/storefront (branch $STOREFRONT_BRANCH) into storefront/"
  git clone --branch "$STOREFRONT_BRANCH" "$STOREFRONT_REPO" storefront
fi

# A clone on the storefront's default branch targets the released Store API —
# the opposite of what this monorepo backend serves.
storefront_head="$(git -C storefront rev-parse --abbrev-ref HEAD)"
if [ "$storefront_head" != "$STOREFRONT_BRANCH" ]; then
  echo "  ! storefront/ is on '$storefront_head', not '$STOREFRONT_BRANCH' — it targets the released Store API." >&2
  echo "    git -C storefront fetch origin && git -C storefront checkout $STOREFRONT_BRANCH" >&2
fi

step "Reading the seeded publishable API keys from the backend"
# Rewritten on every boot, not just at provisioning: the key changes whenever
# the database is reseeded, and a stale key reads as a broken storefront
# rather than a stale config.
KEYS="$(SPREE_PATH="$ROOT" docker compose -f "$DEV_COMPOSE" -f "$EDGE_OVERLAY" exec -T web bin/rails runner - <<'RUBY' | tr -d '\r'
rows = ActiveRecord::Base.connection.select_rows(<<~SQL)
  SELECT COALESCE(c.code, 'default'), k.token
  FROM spree_api_keys k
  JOIN spree_stores s ON s.id = k.store_id
  LEFT JOIN spree_channels c ON c.id = k.channel_id
  WHERE k.key_type = 'publishable'
    AND k.revoked_at IS NULL
    AND k.token IS NOT NULL
    AND s."default"
    AND (k.channel_id IS NULL OR c.code = 'wholesale')
  ORDER BY k.id
SQL
rows.each { |channel, token| puts "#{channel}=#{token}" }
RUBY
)"
key="$(printf '%s\n' "$KEYS" | sed -n 's/^default=//p' | head -1)"
wholesale_key="$(printf '%s\n' "$KEYS" | sed -n 's/^wholesale=//p' | head -1)"

if [ -z "$key" ]; then
  echo "  ! No publishable API key in the database — the storefront will not authenticate." >&2
  echo "    Seed the database (pnpm server:seed), then re-run." >&2
fi

step "Writing storefront/.env.local"
env_file="storefront/.env.local"
marker="# --- your own settings below; everything above is regenerated on boot ---"

# Keep whatever the developer put below the marker (Stripe test keys, GTM, a
# different wholesale channel). grep -F and awk index() both match literally,
# so the marker needs no regex escaping.
custom=""
if [ -f "$env_file" ] && grep -qF "$marker" "$env_file"; then
  custom=$(awk -v m="$marker" 'found { print } index($0, m) { found = 1 }' "$env_file")
fi

{
  printf 'SPREE_API_URL=%s\n' "$API_URL"
  printf 'SPREE_PUBLISHABLE_KEY=%s\n' "$key"
  printf 'NEXT_PUBLIC_SITE_URL=http://localhost:%s\n' "$STOREFRONT_PORT"
  # The wholesale channel only exists in seeded databases; without the code the
  # storefront runs DTC-only and its /wholesale routes 404 by design.
  if [ -n "$wholesale_key" ]; then
    printf 'SPREE_WHOLESALE_CHANNEL=wholesale\n'
    printf 'SPREE_WHOLESALE_PUBLISHABLE_KEY=%s\n' "$wholesale_key"
  fi
  printf '\n%s\n' "$marker"
  # printf '%s\n' rather than '%s': $(...) strips trailing newlines, so the
  # last custom line would otherwise lose its own and merge with whatever a
  # later append writes.
  if [ -n "$custom" ]; then printf '%s\n' "$custom"; fi
} > "$env_file.tmp"
mv "$env_file.tmp" "$env_file"

# Absolute: pnpm resolves the redirected dependency relative to the importer,
# and the same path lands in the storefront's lockfile.
SPREE_SDK_PATH="$ROOT/packages/sdk"
export SPREE_SDK_PATH

step "Building @spree/sdk"
pnpm turbo build --filter='@spree/sdk'

# --no-frozen-lockfile: the pnpmfile redirects @spree/sdk at this checkout, so
# the lockfile necessarily differs from the committed one. Restore it before
# committing inside the clone: git -C storefront checkout pnpm-lock.yaml
step "Installing storefront dependencies (SDK copied from this checkout)"
(cd storefront && pnpm install --silent --no-frozen-lockfile)

step "Starting the storefront"
echo "▸ http://localhost:$STOREFRONT_PORT  (API → $API_URL)"
echo "  SDK changes: rerun this script to rebuild and copy them in."
echo "  storefront/pnpm-lock.yaml now points at this checkout's SDK — don't commit it."
cd storefront
exec pnpm next dev -p "$STOREFRONT_PORT" --turbopack
