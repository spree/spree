#!/usr/bin/env bash
# server-setup.sh — bootstrap a development backend in ./server/ wired up to
# load Spree gems from the monorepo (edge mode).
#
# Sequence:
#   1. Tear down any prior stack + volumes (clean slate, even after a failed run)
#   2. Force-remove ./server/ if it exists (Docker bind-mounted files end up
#      owned by UID 1000 inside the container; on macOS Docker Desktop maps
#      this to the host user, but we still need elevated rm if a prior run
#      left files in odd states).
#   3. Clone spree-starter into server/
#   4. Write server/.env with SPREE_PATH=.. (for the native bin/dev path —
#      Docker edge flow overrides via compose env) + a fresh SECRET_KEY_BASE
#   5. Build @spree/cli so node ../packages/cli/dist/index.js works
#   6. Start the edge stack
#   7. Wait until web container is `running` (not `healthy` — healthcheck
#      polls /up which 500s without a DB)
#   8. CLI: bundle install (rewrites Gemfile.lock to use path-based gems)
#   9. CLI: rake spree:install:migrations (copies migrations from edge gems
#      into server/db/migrate/)
#  10. CLI: rails db:prepare (create + migrate + seed)
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

step "Tearing down any prior stack (this also wipes the dev volumes)"
# Reference the project by name (-p server) rather than via compose files,
# so this works even after a prior run deleted ./server/. Orphan volumes
# from a partially-failed prior run (server_bundle_cache, etc.) cause
# `failed to mkdir /var/lib/docker/volumes/.../ruby: file exists` on the
# next `up` if we don't wipe them here.
docker compose -p server down -v --remove-orphans 2>/dev/null || true

step "Removing any prior $SERVER_DIR"
# Volumes are now released; bind-mounted files are accessible to rm again.
rm -rf "$SERVER_DIR"

step "Cloning spree-starter into server/"
git clone --depth 1 https://github.com/spree/spree-starter.git "$SERVER_DIR"
rm -rf "$SERVER_DIR/.git" "$SERVER_DIR/.gitignore"

step "Writing server/.env (SPREE_PATH + SECRET_KEY_BASE)"
printf 'SPREE_PATH=..\nSECRET_KEY_BASE=%s\n' "$(openssl rand -hex 64)" > "$SERVER_DIR/.env"

step "Building @spree/cli (so node ../packages/cli/dist/index.js works)"
pnpm --filter @spree/cli build

step "Starting the edge stack"
pnpm server:start

step "Waiting for web container to come up"
until docker compose -f "$DEV_COMPOSE" ps web --format '{{.State}}' | grep -q running; do
  sleep 1
done
# Even when running, Rails takes a few seconds to be ready to accept exec.
# A quick warmup avoids the first `docker compose exec` racing the boot.
sleep 5

step "bundle install (rewrites Gemfile.lock against monorepo gems)"
cd "$SERVER_DIR"
SPREE_CLI="$ROOT/packages/cli/dist/index.js"
node "$SPREE_CLI" bundle install

step "spree:install:migrations (copies edge migrations into server/db/migrate/)"
node "$SPREE_CLI" rake spree:install:migrations

step "db:prepare (create + migrate + seed)"
node "$SPREE_CLI" rails db:prepare

printf '\nServer ready: http://localhost:3000\nAdmin:         http://localhost:3000/admin\n\n'
