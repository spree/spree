#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d server ]; then
  echo "→ Cloning spree-starter into ./server"
  git clone --depth 1 https://github.com/spree/spree-starter.git server
  rm -rf server/.git server/.gitignore
fi

# The starter Gemfile reads .env at bundle time. SPREE_PATH=.. makes the
# generated app use the Spree sources from this repository instead of only the
# published gems, which keeps this repo as the backend source of truth.
if ! grep -q '^SPREE_PATH=' server/.env 2>/dev/null; then
  echo "→ Writing server/.env with SPREE_PATH"
  printf 'SPREE_PATH=..\n' > server/.env
fi

cd server

# spree-starter ships with a frozen lockfile resolved against published gems.
# Once SPREE_PATH is enabled, Bundler must rewrite Gemfile.lock to path gems
# from this repository. Render builds are disposable, so this lockfile update is
# safe and intentionally not committed back to the repo.
echo "→ Allowing Bundler to update Gemfile.lock for SPREE_PATH"
bundle config set frozen false
bundle lock --update spree spree_admin spree_core spree_api

echo "→ Installing gems"
bundle install

echo "→ Precompiling assets"
bundle exec rails assets:precompile

echo "→ Preparing database"
bundle exec rails db:prepare
