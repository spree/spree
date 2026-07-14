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
#   5. Build @spree/cli so `pnpm exec spree …` works in server/
#   6. Start the edge stack and wait for it to finish booting. The edge web
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

step "Building the React Dashboard (served at /dashboard via spree_dashboard)"
# The edge overlay points SPREE_DASHBOARD_DIST_PATH at this build output
# through the monorepo mount — no copying, and rebuilds (`pnpm
# server:dashboard`) are served immediately. Non-fatal: the backend works
# without it (/dashboard just 404s until a build exists).
if ! VITE_BASE_PATH=/dashboard/ pnpm --dir "$ROOT/packages/dashboard-starter" build; then
  echo "  ⚠ dashboard build failed — continuing; run 'pnpm server:dashboard' later."
fi

step "Starting the edge stack"
# Detached on purpose — `pnpm server:dev` runs the stack in the foreground
# (streaming logs, Ctrl+C to stop); setup needs to continue past the boot.
SPREE_PATH="$ROOT" docker compose -f "$DEV_COMPOSE" -f "$EDGE_OVERLAY" up -d --force-recreate web worker

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

printf '\nServer ready: http://localhost:3000\nAdmin:         http://localhost:3000/admin\nDashboard:     http://localhost:3000/dashboard\n\n'
