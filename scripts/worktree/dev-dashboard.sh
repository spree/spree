#!/usr/bin/env bash
# Start this worktree's React dashboard (Vite) behind portless, proxying API
# calls to this worktree's Rails URL. URL: https://admin.<branch>.spree.localhost
#
# Vite ignores the PORT env var, so we build the dashboard's workspace deps
# with turbo first, then run vite directly with the portless-assigned port.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_portless
cd "$(worktree_root)"

export VITE_API_PROXY_TARGET
VITE_API_PROXY_TARGET="$(rails_url)"

pnpm turbo build --filter='@spree/dashboard-starter^...'

cd packages/dashboard-starter
echo "▸ $(dashboard_url)  (proxying /api → $VITE_API_PROXY_TARGET)"
exec portless "$(dashboard_name)" sh -c 'exec pnpm vite --port "$PORT" --strictPort'
