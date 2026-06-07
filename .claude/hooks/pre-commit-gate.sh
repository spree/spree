#!/usr/bin/env bash
# Pre-commit/push gate run by Claude Code's PreToolUse hook on git commit/push.
# Runs Biome (formatting + lint) then turbo typecheck (TypeScript) on changed
# files vs main. Exits 2 to block the Bash tool call when either fails, so the
# agent gets the diagnostic back and can fix before CI rejects.
#
# Tools are run sequentially with short-circuit: if Biome fails, typecheck is
# skipped (the Biome diagnostic is enough to act on). Each tool's failure is
# reported separately so the agent knows which to fix.

set -u

cd "$(git rev-parse --show-toplevel)" || exit 1

# 1. Biome — fast (~1s), covers formatting + lint on changed files only.
biome_out=$(pnpm exec biome check --changed --since=main \
  --no-errors-on-unmatched --files-ignore-unknown=true \
  --reporter=summary 2>&1)
biome_exit=$?

if [ $biome_exit -ne 0 ]; then
  echo "Biome check failed on changed files. CI will reject this commit." >&2
  echo "" >&2
  echo "$biome_out" >&2
  echo "" >&2
  echo "Fix: run 'pnpm exec biome check --changed --since=main --write' to apply safe fixes, then resolve any remaining lint errors before committing." >&2
  exit 2
fi

# 2. Turbo typecheck — slower (1-9s depending on cache), runs tsc --noEmit
# across the affected package graph. No --changed flag: turbo invalidates cache
# based on file-content hashes, so untouched packages are instant.
tsc_out=$(pnpm turbo typecheck 2>&1)
tsc_exit=$?

if [ $tsc_exit -ne 0 ]; then
  echo "TypeScript check failed. CI will reject this commit." >&2
  echo "" >&2
  echo "$tsc_out" >&2
  echo "" >&2
  echo "Fix: resolve type errors above, or run 'pnpm turbo typecheck' to see them in context." >&2
  exit 2
fi

exit 0
