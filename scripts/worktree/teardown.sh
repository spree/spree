#!/usr/bin/env bash
# Drop a worktree's databases. Runs from the worktrunk post-remove hook (in the
# primary checkout, with the removed branch passed as $1) or by hand.
set -euo pipefail
WT_BRANCH="${1:-}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Refuse to drop databases still claimed by a checked-out worktree — teardown
# normally runs after the worktree is gone, so a live one means we were pointed
# at the wrong branch.
if git worktree list --porcelain | grep -qx "branch refs/heads/$(branch_name)"; then
  echo "Branch '$(branch_name)' is still checked out in a worktree — refusing to drop its databases." >&2
  echo "Remove the worktree first (wt remove), or drop them by hand if that is really what you want." >&2
  exit 1
fi

for db in "$(db_name)" "$(test_db_name)"; do
  echo "▸ Dropping $db"
  dropdb "${PG_ARGS[@]}" --if-exists "$db"
done
