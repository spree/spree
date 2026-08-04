#!/usr/bin/env bash
# Drop a worktree's databases. Runs from the worktrunk post-remove hook (in the
# primary checkout, with the removed branch passed as $1) or by hand.
set -euo pipefail
WT_BRANCH="${1:-}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

for db in "$(db_name)" "$(test_db_name)"; do
  echo "▸ Dropping $db"
  dropdb "${PG_ARGS[@]}" --if-exists "$db"
done
