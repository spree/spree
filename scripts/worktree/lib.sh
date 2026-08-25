#!/usr/bin/env bash
# Shared helpers for the multi-worktree dev workflow (see CLAUDE.md "Worktrees").
# Everything derives from the current git branch, so the scripts work both from
# worktrunk hooks and when run by hand. Pass a branch name as WT_BRANCH (or as
# the first argument to the calling script) to operate on another worktree's
# resources, e.g. from a post-remove hook running in the primary checkout.
set -euo pipefail

TEMPLATE_DB="spree_worktree_template"
# The storefront's 6.0 line. Its main branch stays on the released Store API for
# people forking or deploying it; 6-0-dev tracks the unreleased one we build here.
STOREFRONT_REPO="https://github.com/spree/storefront.git"
STOREFRONT_BRANCH="6-0-dev"
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
storefront_name() { echo "store.$(branch_slug).spree"; }
rails_url() { echo "https://$(rails_name).localhost$(url_suffix)"; }
dashboard_url() { echo "https://$(dashboard_name).localhost$(url_suffix)"; }
storefront_url() { echo "https://$(storefront_name).localhost$(url_suffix)"; }
# The marketplace seller panel — a separate app from the operator's dashboard,
# so it gets its own host rather than a route inside it.
seller_name() { echo "sellers.$(branch_slug).spree"; }
seller_url() { echo "https://$(seller_name).localhost$(url_suffix)"; }
# RAILS_HOST wants a bare host with an optional port, no scheme.
rails_host() { echo "$(rails_name).localhost$(url_suffix)"; }

port_free() { ! lsof -iTCP:"$1" -sTCP:LISTEN -n -P >/dev/null 2>&1; }

# Publishable API keys of the default store, read straight from Postgres — the
# token column is plaintext for publishable keys (only secret keys are hashed),
# so the storefront can be wired up without booting Rails.
#
# $1 selects the channel binding: "default" for the unbound key the DTC
# storefront uses, or a channel code for a bound one (the wholesale portal).
# Prints nothing when there is no such key, which callers treat as "skip".
publishable_key() {
  local binding="${1:-default}" filter

  if [ "$binding" = "default" ]; then
    filter="k.channel_id IS NULL"
  else
    filter="c.code = '${binding//\'/\'\'}'"
  fi

  psql "${PG_ARGS[@]}" -d "$(db_name)" -tAc "
    SELECT k.token
    FROM spree_api_keys k
    JOIN spree_stores s ON s.id = k.store_id
    LEFT JOIN spree_channels c ON c.id = k.channel_id
    WHERE k.key_type = 'publishable'
      AND k.revoked_at IS NULL
      AND k.token IS NOT NULL
      AND s.default
      AND $filter
    ORDER BY k.id
    LIMIT 1;
  " 2>/dev/null | tr -d '[:space:]'
}

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

# Write storefront/.env.local from this worktree's Rails URL and seeded keys.
#
# Called on every storefront boot, not just at provisioning: the publishable key
# lives in the worktree's database, so it changes whenever the database is
# reseeded or recreated from a newer template. A stale key authenticates as
# another store — or nothing at all — which reads as a broken storefront rather
# than a stale config, so it is cheaper to rewrite the file than to detect drift.
# Anything a developer adds below the generated block is preserved.
write_storefront_env() {
  local env_file="storefront/.env.local" key wholesale_key
  local marker="# --- your own settings below; everything above is regenerated on boot ---"

  key="$(publishable_key default)"
  if [ -z "$key" ]; then
    echo "  ! No publishable API key in $(db_name) — storefront will not authenticate." >&2
    echo "    Seed the database (cd server && bin/rails db:seed), then re-run." >&2
  fi
  wholesale_key="$(publishable_key wholesale)"

  # Keep whatever the developer put below the marker (Stripe test keys, GTM, a
  # different wholesale channel). grep -F and awk index() both match literally,
  # so the marker needs no regex escaping.
  local custom=""
  if [ -f "$env_file" ] && grep -qF "$marker" "$env_file"; then
    custom=$(awk -v m="$marker" 'found { print } index($0, m) { found = 1 }' "$env_file")
  fi

  {
    printf 'SPREE_API_URL=%s\n' "$(rails_url)"
    printf 'SPREE_PUBLISHABLE_KEY=%s\n' "$key"
    printf 'NEXT_PUBLIC_SITE_URL=%s\n' "$(storefront_url)"
    # The wholesale channel only exists in seeded databases; without the code the
    # storefront runs DTC-only and its /wholesale routes 404 by design.
    if [ -n "$wholesale_key" ]; then
      printf 'SPREE_WHOLESALE_CHANNEL=wholesale\n'
      printf 'SPREE_WHOLESALE_PUBLISHABLE_KEY=%s\n' "$wholesale_key"
    fi
    printf '\n%s\n' "$marker"
    # printf '%s\n' rather than '%s': $(...) strips trailing newlines, so the
    # last custom line would otherwise lose its own and merge with whatever a
    # later append writes.
    [ -n "$custom" ] && printf '%s\n' "$custom"
  } > "$env_file.tmp"
  mv "$env_file.tmp" "$env_file"
}

require_portless() {
  command -v portless >/dev/null || {
    echo "portless not found — install with: npm install -g portless (Node >= 24)" >&2
    exit 1
  }
}

# Mailpit catches every email the dev server sends, the same way it does in the
# starter's Docker stack. One instance serves every worktree, like Postgres.
MAILPIT_HOST="${MAILPIT_HOST:-localhost}"
MAILPIT_SMTP_PORT="${MAILPIT_SMTP_PORT:-1025}"
MAILPIT_UI_PORT="${MAILPIT_UI_PORT:-8025}"
mailpit_url() { echo "http://localhost:$MAILPIT_UI_PORT"; }

# A warning rather than a hard failure: a worktree is still usable without it,
# and only the screens that send mail are affected.
warn_unless_mailpit() {
  port_free "$MAILPIT_SMTP_PORT" || return 0
  echo "  ! Mailpit is not running — email will fail to deliver."
  echo "    brew install mailpit && brew services start mailpit"
}
