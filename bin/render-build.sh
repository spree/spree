#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d server ]; then
  echo "→ Cloning spree-starter into ./server"
  git clone --depth 1 https://github.com/spree/spree-starter.git server
  rm -rf server/.git server/.gitignore
fi

# On Render, deploy the generated Spree app with the starter lockfile and
# published Spree gems. Avoid SPREE_PATH here because switching to local path
# gems requires rewriting Gemfile.lock during the build, which is fragile on
# Render's Ruby bootstrap environment.
rm -f server/.env

cd server

echo "→ Installing gems"
bundle config set frozen true
bundle install

echo "→ Precompiling assets"
bundle exec rails assets:precompile

echo "→ Preparing database"
bundle exec rails db:prepare
