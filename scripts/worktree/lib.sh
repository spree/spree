#!/usr/bin/env bash
# Shared helpers for the multi-worktree dev workflow (see CLAUDE.md "Worktrees").
# Everything derives from the current git branch, so the scripts work both from
# worktrunk hooks and when run by hand. Pass a branch name as WT_BRANCH (or as
# the first argument to the calling script) to operate on another worktree's
# resources, e.g. from a post-remove hook running in the primary checkout.
set -euo pipefail

TEMPLATE_DB="spree_worktree_template"
PG_ARGS=(-h localhost -p "${DATABASE_PORT:-5432}" -U "${DATABASE_USERNAME:-postgres}")

worktree_root() { git rev-parse --show-toplevel; }

branch_slug() {
  local branch="${WT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
  printf '%s' "$branch" | tr '/_.' '-' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | cut -c1-40
}

db_name() { echo "spree_dev_$(branch_slug | tr '-' '_')"; }
test_db_name() { echo "spree_test_$(branch_slug | tr '-' '_')"; }

db_exists() { psql "${PG_ARGS[@]}" -lqt | cut -d'|' -f1 | tr -d ' ' | grep -qx "$1"; }

# portless serves https on 443 when its proxy could bind it, otherwise on the
# fallback port recorded in ~/.portless/proxy.port — derive URLs dynamically so
# moving the proxy to 443 later needs no script or env changes.
portless_port() { cat "$HOME/.portless/proxy.port" 2>/dev/null || echo 443; }
url_suffix() { [ "$(portless_port)" = "443" ] && echo "" || echo ":$(portless_port)"; }

rails_name() { echo "$(branch_slug).spree"; }
dashboard_name() { echo "admin.$(branch_slug).spree"; }
rails_url() { echo "https://$(rails_name).localhost$(url_suffix)"; }
dashboard_url() { echo "https://$(dashboard_name).localhost$(url_suffix)"; }

# Deterministic even-numbered base in 20000–29999: rails = base, vite = base+1.
e2e_base_port() {
  local hash
  hash=$(printf '%s' "$(branch_slug)" | cksum | cut -d' ' -f1)
  echo $((20000 + (hash % 5000) * 2))
}

require_portless() {
  command -v portless >/dev/null || {
    echo "portless not found — install with: npm install -g portless (Node >= 24)" >&2
    exit 1
  }
}
