#!/usr/bin/env bash
# server-setup.sh — bootstrap a development backend in ./server/ wired up to
# load Spree gems from the monorepo (edge mode).
#
# Sequence:
#   1. Tear down any prior stack + volumes and remove ./server/ (via
#      server-teardown.sh — clean slate, even after a failed run; also
#      available standalone as `pnpm server:teardown`)
#   2. Clone spree-starter into server/
#   3. Write server/.env with SPREE_PATH=.. (for the native bin/dev path —
#      Docker edge flow overrides via compose env) + a fresh SECRET_KEY_BASE
#   4. Build @spree/cli so `pnpm exec spree …` works in server/
#   5. Start the edge stack and wait for it to finish booting. The edge web
#      boot command (scripts/docker-compose.edge.yml) does the heavy lifting
#      itself — bundle install against the monorepo gems (rewrites
#      Gemfile.lock with the PATH block), spree:install:migrations, and
#      db:prepare (create + migrate + seed) — so this script must NOT run
#      those steps too: a second bundle install / db:prepare racing the
#      boot's own can corrupt the bundle_cache volume or trip over a
#      half-prepared database. We just wait until the web server answers.
#
# Idempotent: re-running this from any state should converge. The volume
# nuke in step 1 is what makes it idempotent in the face of partially-failed
# prior runs.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEV_COMPOSE="server/docker-compose.dev.yml"
EDGE_OVERLAY="scripts/docker-compose.edge.yml"
SERVER_DIR="$ROOT/server"

step() { printf '\n→ %s\n' "$1"; }

bash "$ROOT/scripts/server-teardown.sh" --no-hint

step "Cloning spree-starter into server/ (branch: ${SPREE_STARTER_BRANCH:-6-0-dev})"
git clone --depth 1 --branch "${SPREE_STARTER_BRANCH:-6-0-dev}" https://github.com/spree/spree-starter.git "$SERVER_DIR"
rm -rf "$SERVER_DIR/.git" "$SERVER_DIR/.gitignore"

step "Writing server/.env (SPREE_PATH + SECRET_KEY_BASE)"
printf 'SPREE_PATH=..\nSECRET_KEY_BASE=%s\n' "$(openssl rand -hex 64)" > "$SERVER_DIR/.env"

step "Building @spree/cli (so the spree CLI works in server/)"
# Through turbo, which builds workspace deps first (build dependsOn ^build) —
# a bare `pnpm --filter @spree/cli build` fails on a clean clone with
# `Could not resolve "@spree/admin-sdk"` because packages/admin-sdk/dist
# doesn't exist yet.
pnpm turbo build --filter=@spree/cli

# On a clean clone `pnpm install` runs before the CLI is ever built, and pnpm
# only links a workspace bin whose target file exists — so the `spree` shim
# is silently skipped, and a later `pnpm install` (even --force) does not
# recreate it. Link it ourselves now that the build exists; dist/index.js
# carries a node shebang and is executable, so a plain symlink works.
if [ ! -e "$ROOT/node_modules/.bin/spree" ]; then
  step "Linking the missing spree bin shim"
  mkdir -p "$ROOT/node_modules/.bin"
  ln -sf ../../packages/cli/dist/index.js "$ROOT/node_modules/.bin/spree"
fi

step "Starting the edge stack"
# Detached on purpose — `pnpm server:dev` runs the stack in the foreground
# (streaming logs, Ctrl+C to stop); setup needs to continue past the boot.
# SPREE_MEILISEARCH opts into the Meilisearch search provider overlay, same
# as `pnpm server:dev` (safe under set -u: :+ is exempt from nounset).
SPREE_PATH="$ROOT" docker compose -f "$DEV_COMPOSE" -f "$EDGE_OVERLAY" ${SPREE_MEILISEARCH:+-f scripts/docker-compose.meilisearch.yml} up -d --force-recreate web

step "Waiting for the stack to finish booting"
# The edge web boot runs bundle install + spree:install:migrations +
# db:prepare before starting Puma (see scripts/docker-compose.edge.yml), so
# "web answers HTTP" means the whole bootstrap is done. First boot installs
# the monorepo spree gems into the bundle_cache volume — give it minutes,
# not seconds. Do NOT add exec-based setup steps here; they would race the
# boot's own sequence.
WAIT_TIMEOUT=600
elapsed=0
until code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://localhost:3000/ 2>/dev/null)" && [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; do
  if [ "$elapsed" -ge "$WAIT_TIMEOUT" ]; then
    echo "✗ web did not respond within ${WAIT_TIMEOUT}s." >&2
    echo "  Inspect with: docker compose -f $DEV_COMPOSE logs web" >&2
    exit 1
  fi
  if [ "$elapsed" -gt 0 ] && [ $((elapsed % 30)) -eq 0 ]; then
    echo "  …still booting (${elapsed}s) — gems + migrations + seeds run on first boot."
    echo "     Follow along: docker compose -f $DEV_COMPOSE logs -f web"
  fi
  sleep 3
  elapsed=$((elapsed + 3))
done

step "Fetching the one-time first-run setup link"
# The seed announces the setup URL, but during this flow that lands in the
# detached container's logs where nobody sees it. Ask the running app to
# print it again. The task refuses once an admin account exists (e.g.
# ADMIN_EMAIL/ADMIN_PASSWORD were set at seed time), so an empty result is
# informational, not an error.
SETUP_URL="$(SPREE_PATH="$ROOT" docker compose -f "$DEV_COMPOSE" -f "$EDGE_OVERLAY" exec -T web bin/rails spree:setup:token 2>/dev/null | tr -d '\r' | grep -oE 'https?://[^[:space:]]+' | tail -1 || true)"

printf '\nBackend ready: http://localhost:3000\n\n'
printf 'The React dashboard, seller panel and storefront run as their own dev servers:\n'
printf '  pnpm dashboard:dev   # admin dashboard → http://localhost:5173\n'
printf '  pnpm seller:dev      # seller panel    → http://localhost:5174\n'
printf '  pnpm storefront:dev  # storefront      → http://localhost:3001\n\n'
if [ -n "$SETUP_URL" ]; then
  printf 'Then create the first admin account (one-time link, needs dashboard:dev running):\n  %s\n\n' "$SETUP_URL"
  printf 'Print it again later with:\n  SPREE_PATH="$PWD" docker compose -f %s -f %s exec web bin/rails spree:setup:token\n\n' "$DEV_COMPOSE" "$EDGE_OVERLAY"
else
  printf 'No first-run setup link — an admin account already exists. Sign in at the dashboard.\n\n'
fi
