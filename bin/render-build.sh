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

echo "→ Installing gems"
bundle install

echo "→ Precompiling assets"
bundle exec rails assets:precompile

echo "→ Preparing database"
bundle exec rails db:prepare
