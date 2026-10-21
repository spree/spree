#!/usr/bin/env bash
# Prepare a Claude Code cloud session: start Postgres and Mailpit, clone the
# starter into server/, install gems and node modules, and create + seed the
# database on first boot. Runs from the SessionStart hook on every start and
# resume (a paused VM loses its processes, not its files), so every step is
# idempotent and cheap the second time. Only stdout reaches the agent, so the
# steps log to $LOG and the summary at the end is what it reads.
#
# Cloud only — on a laptop use the worktree scripts (scripts/worktree/).
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

LOG=/tmp/spree-cloud-provision.log
DATABASE_NAME=spree_development
ADMIN_EMAIL=spree@example.com
ADMIN_PASSWORD=spree123

step() { echo "▸ $*" >>"$LOG"; }
fail() { echo "✗ Cloud provisioning failed: $* — see $LOG"; exit 1; }
as_root() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }

: >"$LOG"

step "Starting Postgres"
as_root service postgresql start >>"$LOG" 2>&1 || fail "Postgres did not start"
for _ in $(seq 1 30); do pg_isready -q -h localhost && break; sleep 1; done

if command -v mailpit >/dev/null && ! lsof -iTCP:1025 -sTCP:LISTEN >/dev/null 2>&1; then
  step "Starting Mailpit"
  nohup mailpit >/tmp/spree-mailpit.log 2>&1 &
fi

if [ ! -d server ]; then
  step "Cloning spree-starter into server/"
  git clone --quiet --depth 1 https://github.com/spree/spree-starter.git server >>"$LOG" 2>&1 || fail "could not clone spree-starter"
  rm -rf server/.git server/.gitignore
fi

ruby_version=$(cat server/.ruby-version)
ruby_bin="/opt/rubies/$ruby_version/bin"
[ -x "$ruby_bin/ruby" ] || fail "Ruby $ruby_version is not installed — bump RUBY_VERSION in scripts/cloud/environment-setup.sh and paste it into the environment's setup script"
export PATH="$ruby_bin:$PATH"

# Later Bash commands in the session read this file, so ruby/bundle resolve to
# the starter's version rather than the image's rbenv ones.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"$ruby_bin:\$PATH\""
    echo "export PLAYWRIGHT_BROWSERS_PATH=\"\${PLAYWRIGHT_BROWSERS_PATH:-/opt/ms-playwright}\""
  } >>"$CLAUDE_ENV_FILE"
fi

if [ ! -f server/.env ]; then
  step "Writing server/.env"
  cat >server/.env <<EOF
SPREE_PATH=$(pwd)
SECRET_KEY_BASE=$(openssl rand -hex 64)
DATABASE_NAME=$DATABASE_NAME
DATABASE_NAME_TEST=spree_test
SPREE_DASHBOARD_URL=http://localhost:5173
SPREE_SELLER_PANEL_URL=http://localhost:5175
RAILS_HOST=localhost:3000
RAILS_PROTOCOL=http
SMTP_HOST=localhost
SMTP_PORT=1025
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 16)
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 16)
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 16)
EOF
fi

step "Installing gems"
(cd server && { bundle check >/dev/null 2>&1 || bundle install --quiet; }) >>"$LOG" 2>&1 || fail "bundle install"

if psql -h localhost -U postgres -lqt | cut -d'|' -f1 | tr -d ' ' | grep -qx "$DATABASE_NAME"; then
  step "Migrating $DATABASE_NAME"
  (cd server && bin/rails spree:install:migrations db:migrate) >>"$LOG" 2>&1 || fail "db:migrate"
else
  step "Creating and seeding $DATABASE_NAME (first boot, a few minutes)"
  (cd server && ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" \
    bin/rails db:create spree:install:migrations db:migrate db:seed) >>"$LOG" 2>&1 || fail "database setup"
fi

lock_hash=$(sha1sum pnpm-lock.yaml | cut -c1-40)
if [ "$(cat node_modules/.cloud-lock-hash 2>/dev/null)" != "$lock_hash" ]; then
  step "Installing node modules"
  pnpm install --silent >>"$LOG" 2>&1 || fail "pnpm install"
  echo "$lock_hash" >node_modules/.cloud-lock-hash
fi

for app in dashboard-starter seller-dashboard-starter; do
  printf 'VITE_API_PROXY_TARGET=http://localhost:3000\n' >"packages/$app/.env.local"
done

cat <<EOF
✓ Spree cloud environment ready (Ruby $ruby_version, database $DATABASE_NAME, log $LOG)
  Start servers:   scripts/cloud/start.sh [rails|dashboard|seller|all]   (default: rails + dashboard)
  Rails API:       http://localhost:3000   (log /tmp/spree-rails.log)
  Admin dashboard: http://localhost:5173   ($ADMIN_EMAIL / $ADMIN_PASSWORD)
  Seller panel:    http://localhost:5175   (seed a seller: cd server && bin/rails spree:sellers:sample_data)
  Look at a page:  node scripts/cloud/screenshot.mjs http://localhost:5173/ /tmp/page.png --login   then Read the PNG
  Email:           http://localhost:8025/api/v1/messages   (Mailpit)
  Only you can see these servers: the person using the app has no browser preview of them.
EOF
