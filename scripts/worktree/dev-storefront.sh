#!/usr/bin/env bash
# Start this worktree's Next.js storefront behind portless, against this
# worktree's Rails and this worktree's @spree/sdk build.
# URL: https://store.<branch>.spree.localhost
#
# The storefront is a separate repo (spree/storefront, branch 6-0-dev) cloned
# into storefront/ by setup.sh. It has its own pnpm project — deliberately not a
# member of this workspace, whose single lockfile and global overrides would
# have to cover Next 16 and the dashboard's Vite tree at once.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_portless
cd "$(worktree_root)"

if [ ! -d storefront ]; then
  echo "storefront/ is missing — run pnpm wt:setup to clone it." >&2
  exit 1
fi

# A clone made before 6-0-dev was pushed sits on the storefront's default
# branch, which targets the released Store API — the opposite of what this
# worktree is for. Say so rather than let 6.0 changes look broken.
storefront_head=$(git -C storefront rev-parse --abbrev-ref HEAD)
if [ "$storefront_head" != "$STOREFRONT_BRANCH" ]; then
  echo "  ! storefront/ is on '$storefront_head', not '$STOREFRONT_BRANCH' — it targets the released Store API." >&2
  echo "    git -C storefront fetch origin && git -C storefront checkout $STOREFRONT_BRANCH" >&2
fi

# Absolute: pnpm resolves link: targets relative to the importer, and the same
# path is written into the storefront's lockfile.
SPREE_SDK_PATH="$(pwd)/packages/sdk"
export SPREE_SDK_PATH

write_storefront_env

echo "▸ Building @spree/sdk"
pnpm turbo build --filter='@spree/sdk'

# --no-frozen-lockfile: the pnpmfile redirects @spree/sdk at this worktree, so
# the lockfile necessarily differs from the committed one.
#
# That diff is left visible on purpose. Hiding it (skip-worktree) makes any pull
# that touches the lockfile fail with a misleading "local changes would be
# overwritten" — a worse trap than the diff. Restore it before committing in the
# clone: git checkout pnpm-lock.yaml
echo "▸ Installing storefront dependencies (SDK copied from this worktree)"
(cd storefront && pnpm install --silent --no-frozen-lockfile)

# The clone lives inside the worktree, so `wt remove` takes it — and any commits
# in it — along with everything else. Cheap to say once per boot.
if [ -n "$(git -C storefront log --branches --not --remotes --oneline 2>/dev/null)" ]; then
  echo "  ! storefront/ has commits that are not on its remote — push before wt remove." >&2
fi

# Resolved before the cd below: every name here derives from the current git
# branch, and inside storefront/ that is the storefront's branch, not this
# worktree's — which would put the site on a URL keyed to the wrong worktree.
storefront_host="$(storefront_name)"
banner="▸ $(storefront_url)  (API → $(rails_url))"

cd storefront
echo "$banner"
echo "  SDK changes: rerun this script to rebuild and copy them in."
echo "  storefront/pnpm-lock.yaml now points at this worktree's SDK — don't commit it."
portless "$storefront_host" sh -c 'exec pnpm next dev -p "$PORT" --turbopack'
