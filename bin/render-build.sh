#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SERVER_DIR="$ROOT/server"
NEXT_SERVER_DIR="$ROOT/server.next"
STAMP="$(date +%s)"

if [ -e "$NEXT_SERVER_DIR" ]; then
  echo "→ Moving leftover ./server.next out of the way"
  mv "$NEXT_SERVER_DIR" "$ROOT/server.next.stale.$STAMP"
fi

echo "→ Cloning fresh spree-starter into ./server.next"
git clone --depth 1 https://github.com/spree/spree-starter.git "$NEXT_SERVER_DIR"

if [ -e "$SERVER_DIR" ]; then
  echo "→ Moving cached ./server out of the active build path"
  mv "$SERVER_DIR" "$ROOT/server.stale.$STAMP"
fi

mv "$NEXT_SERVER_DIR" "$SERVER_DIR"

# Render currently builds this service reliably with Ruby 3.4.4. The upstream
# starter pins Ruby 4.0.1, which triggers Render's Ruby installer during Bundler
# execution and fails in this environment. Rails/Spree dependencies support Ruby
# 3.4.x here, so keep the generated app aligned with the root runtime.
echo "3.4.4" > server/.ruby-version

# Deploy with THIS fork's Spree gems (spree/core, spree/api, spree/admin,
# spree/emails) rather than the published RubyGems releases, so changes made
# in this repo (translations, branding, custom routes/behavior) actually
# reach this deployment. spree-starter's Gemfile reads server/.env before
# Bundler resolves dependencies, so keep SPREE_PATH persisted there too.
printf 'SPREE_PATH=%s\n' "$ROOT" > server/.env

cd server

# Rails needs a secret while loading the production environment for asset
# precompilation. Render should still provide a real SECRET_KEY_BASE at runtime.
export SECRET_KEY_BASE_DUMMY=1
export SPREE_PATH="$ROOT"
export BUNDLE_FROZEN=false
export BUNDLE_DEPLOYMENT=false
export BUNDLE_PATH="/opt/render/project/.gems"

echo "→ Installing gems (local Spree gems via SPREE_PATH=$SPREE_PATH)"
# Ignore stale local Bundler config from a cached server directory. The active
# server directory is freshly cloned above, and these env vars keep Bundler in
# the same non-frozen path-gem context for lock, install, check and Rails boot.
BUNDLE_IGNORE_CONFIG=1 bundle lock
BUNDLE_IGNORE_CONFIG=1 bundle install
BUNDLE_IGNORE_CONFIG=1 bundle check

echo "→ Precompiling assets"
BUNDLE_IGNORE_CONFIG=1 bundle exec rails assets:precompile

if [ -n "${DATABASE_URL:-}" ]; then
  echo "→ Preparing database"
  BUNDLE_IGNORE_CONFIG=1 bundle exec rails db:prepare
else
  echo "→ Skipping database preparation because DATABASE_URL is not set"
fi
