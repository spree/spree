#!/usr/bin/env bash
# Setup script for the Claude Code cloud environment (claude.ai/code and the
# desktop app's Cloud sessions). Paste it into the environment's "Setup script"
# field — see "Claude Code cloud sessions" in
# docs/developer/contributing/developing-spree.mdx.
#
# Runs as root on Ubuntu before the session starts. Anthropic snapshots the
# filesystem when it finishes within about five minutes, so this installs only
# machine-level tools (no gems, node modules or database — the session start
# hook in scripts/cloud/provision.sh owns those, because they follow the branch).
set -euo pipefail

RUBY_VERSION=4.0.5
RV_RUBY_RELEASE=20260929
PNPM_VERSION=11.1.1
PLAYWRIGHT_VERSION=1.64.1

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends libvips42t64 libpq-dev libyaml-dev lsof >/dev/null

# Precompiled, relocatable Ruby: building 4.0.x from source alone would use
# most of the five-minute snapshot budget, and the image ships only 3.1-3.3.
if [ ! -x "/opt/rubies/$RUBY_VERSION/bin/ruby" ]; then
  mkdir -p /opt/rubies
  curl -fsSL "https://github.com/spinel-coop/rv-ruby/releases/download/$RV_RUBY_RELEASE/ruby-$RUBY_VERSION.x86_64_linux.tar.gz" \
    | tar xz -C /opt/rubies --strip-components=1
fi
chmod -R a+rwX /opt/rubies

npm install -g --silent "pnpm@$PNPM_VERSION"

# Catches every email the app sends, as it does on the laptop.
if ! command -v mailpit >/dev/null; then
  curl -fsSL https://github.com/axllent/mailpit/releases/latest/download/mailpit-linux-amd64.tar.gz \
    | tar xz -C /usr/local/bin mailpit
fi

# Local throwaway database: trust loopback connections so the starter's
# database.yml (no password) connects as postgres.
for hba in /etc/postgresql/*/main/pg_hba.conf; do
  sed -i -E 's/^(host[[:space:]]+all[[:space:]]+all[[:space:]]+(127\.0\.0\.1\/32|::1\/128)[[:space:]]+)[^[:space:]]+/\1trust/' "$hba"
done

# Version pinned to the dashboard's lockfile. Needs cdn.playwright.dev and
# playwright.download.prss.microsoft.com on the allowed hosts; without them the
# environment still starts, but the browser is missing.
export PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
npx -y "playwright@$PLAYWRIGHT_VERSION" install --with-deps chromium \
  || echo "! Chromium download failed — add the Playwright hosts to the environment's allowed domains"
chmod -R a+rX /opt/ms-playwright 2>/dev/null || true
