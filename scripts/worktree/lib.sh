#!/usr/bin/env bash
# Shared helpers for the multi-worktree dev workflow (see CLAUDE.md "Worktrees").
# Everything derives from the current git branch, so the scripts work both from
# worktrunk hooks and when run by hand. Pass a branch name as WT_BRANCH (or as
# the first argument to the calling script) to operate on another worktree's
# resources, e.g. from a post-remove hook running in the primary checkout.
set -euo pipefail

TEMPLATE_DB="spree_worktree_template"
# Same defaults as the starter's config/database.yml, so the psql tools and
# Rails always agree on which server they are talking to. teardown runs after
# the worktree (and its bundled Rails) is gone, so these cannot come from Rails.
PG_ARGS=(-h "${DATABASE_HOST:-localhost}" -p "${DATABASE_PORT:-5432}" -U "${DATABASE_USERNAME:-postgres}")

worktree_root() { git rev-parse --show-toplevel; }

# Both pieces below arrived in spree/spree-starter#1376. A clone predating it
# passes provisioning but then either shares the default database or rejects
# every proxied request, so check both before touching anything.
# Renders database.yml with sentinel values and applies the host rule, rather
# than grepping for tokens: a comment, or the same token in the wrong YAML
# entry, would otherwise vouch for a config that still points at the defaults.
# Ruby only — no Rails boot, so this runs before `bundle install`.
require_current_starter() {
  local missing=()
  local report

  report=$(cd server && DATABASE_NAME=__dev_probe__ DATABASE_NAME_TEST=__test_probe__ ruby -ryaml -rerb -e '
    config = YAML.safe_load(ERB.new(File.read("config/database.yml")).result, aliases: true)
    puts "dev"  if config.dig("development", "database") == "__dev_probe__"
    puts "test" if config.dig("test", "database") == "__test_probe__"
    puts "host" if File.read("config/environments/development.rb")
                       .then { |src| src[/config\.hosts\s*<<\s*(\S+localhost\S+)/, 1] }
                       &.then { |rule| eval(rule) =~ "feature-x.spree.localhost:1355" }
  ' 2>/dev/null) || true

  grep -qx dev  <<<"$report" || missing+=("config/database.yml: the development entry ignores DATABASE_NAME — worktrees would share spree_development")
  grep -qx test <<<"$report" || missing+=("config/database.yml: the test entry ignores DATABASE_NAME_TEST — worktrees would share spree_test")
  grep -qx host <<<"$report" || missing+=("config/environments/development.rb: no host rule accepting proxied .localhost names — Rails would block every request")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "This server/ clone predates spree-starter#1376:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    echo "Refresh it: rm -rf server && re-run scripts/worktree/setup.sh" >&2
    return 1
  fi
}

branch_name() { echo "${WT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"; }

# Readable prefix plus a hash of the full branch name: normalization alone maps
# feature/a, feature_a and feature.a onto one slug — and databases are dropped
# by slug, so a collision means one worktree deleting another's data.
branch_slug() {
  local branch prefix hash
  branch="$(branch_name)"
  prefix=$(printf '%s' "$branch" | tr '/_.' '-' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | cut -c1-32)
  hash=$(printf '%s' "$branch" | shasum | cut -c1-6)
  echo "${prefix%-}-$hash"
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

port_free() { ! lsof -iTCP:"$1" -sTCP:LISTEN -n -P >/dev/null 2>&1; }

# Even-numbered base in 20000-29999 (rails = base, vite = base+1), derived from
# the branch so repeat runs reuse it. The hash space is smaller than the set of
# branch names, so step to the next free pair when another run already holds it.
e2e_base_port() {
  local hash base candidate offset
  hash=$(printf '%s' "$(branch_slug)" | cksum | cut -d' ' -f1)
  base=$((20000 + (hash % 5000) * 2))
  for offset in $(seq 0 2 998); do
    candidate=$(( 20000 + ((base - 20000 + offset) % 10000) ))
    if port_free "$candidate" && port_free $((candidate + 1)); then
      echo "$candidate"
      return 0
    fi
  done
  echo "No free e2e port pair in 20000-29999." >&2
  return 1
}

require_portless() {
  command -v portless >/dev/null || {
    echo "portless not found — install with: npm install -g portless (Node >= 24)" >&2
    exit 1
  }
}
