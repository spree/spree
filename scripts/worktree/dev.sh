#!/usr/bin/env bash
# Start this worktree's Rails server behind portless. One Puma process — jobs
# run inside it via Solid Queue. URL: https://<branch>.spree.localhost
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_portless
cd "$(worktree_root)/server"

echo "▸ $(rails_url)  (/up, /api/v3, /jobs)"
exec portless "$(rails_name)" bin/dev
