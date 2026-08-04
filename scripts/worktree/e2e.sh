#!/usr/bin/env bash
# Run the dashboard Playwright suite on this worktree's deterministic port
# block, so multiple worktrees can run e2e concurrently. The suite already
# isolates its database (per-worktree SQLite in spree/api/spec/dummy).
# Extra args pass through to playwright: scripts/worktree/e2e.sh e2e/auth.spec.ts
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [ ! -d "$(worktree_root)/spree/api/spec/dummy" ]; then
  echo "spree/api/spec/dummy missing — the e2e suite needs the API test app." >&2
  echo "Build it once per worktree: cd spree/api && bundle install && bundle exec rake test_app" >&2
  exit 1
fi

E2E_RAILS_PORT=$(e2e_base_port)
E2E_VITE_PORT=$((E2E_RAILS_PORT + 1))
export E2E_RAILS_PORT E2E_VITE_PORT

echo "▸ e2e on rails :$E2E_RAILS_PORT / vite :$E2E_VITE_PORT"
cd "$(worktree_root)/packages/dashboard"
exec pnpm test:e2e "$@"
