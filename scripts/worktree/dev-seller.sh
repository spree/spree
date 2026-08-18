#!/usr/bin/env bash
# Start this worktree's seller panel (Vite) behind portless, proxying API
# calls to this worktree's Rails URL. URL: https://sellers.<branch>.spree.localhost
#
# The seller panel is its own app, not a route inside the operator's
# dashboard, so it runs as a second process on its own host — sign in as a
# seller here, as marketplace staff on the admin host.
#
# Vite ignores the PORT env var, so we build the panel's workspace deps with
# turbo first, then run vite directly with the portless-assigned port.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_portless
cd "$(worktree_root)"

export VITE_API_PROXY_TARGET
VITE_API_PROXY_TARGET="$(rails_url)"

pnpm turbo build --filter='@spree/seller-dashboard-starter^...'

cd packages/seller-dashboard-starter
echo "▸ $(seller_url)  (proxying /api → $VITE_API_PROXY_TARGET)"
exec portless "$(seller_name)" sh -c 'exec pnpm vite --port "$PORT" --strictPort'
