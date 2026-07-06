#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d server ]; then
  echo "→ Cloning spree-starter into ./server"
  git clone --depth 1 https://github.com/spree/spree-starter.git server
  rm -rf server/.git server/.gitignore
fi

# Render currently builds this service reliably with Ruby 3.4.4. The upstream
# starter pins Ruby 4.0.1, which triggers Render's Ruby installer during Bundler
# execution and fails in this environment. Rails/Spree dependencies support Ruby
# 3.4.x here, so keep the generated app aligned with the root runtime.
echo "3.4.4" > server/.ruby-version

# Deploy with THIS fork's Spree gems (spree/core, spree/api, spree/admin,
# spree/emails) rather than the published RubyGems releases, so changes made
# in this repo (translations, branding, custom routes/behavior) actually
# reach this deployment. spree-starter's Gemfile has a `SPREE_PATH`
# conditional exactly for this ("SPREE_PATH set -> local gems").
rm -f server/.env

cd server

# Rails needs a secret while loading the production environment for asset
# precompilation. Render should still provide a real SECRET_KEY_BASE at runtime.
export SECRET_KEY_BASE_DUMMY=1
export SPREE_PATH="$ROOT"

echo "→ Installing gems (local Spree gems via SPREE_PATH=$SPREE_PATH)"
bundle config set frozen false
bundle install

echo "→ Precompiling assets"
bundle exec rails assets:precompile

if [ -n "${DATABASE_URL:-}" ]; then
  echo "→ Preparing database"
  bundle exec rails db:prepare
else
  echo "→ Skipping database preparation because DATABASE_URL is not set"
fi
