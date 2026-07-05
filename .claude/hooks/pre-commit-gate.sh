#!/usr/bin/env bash
# Pre-commit/push gate invoked by Claude Code's PreToolUse hook for every Bash
# tool call. Inspects the command on stdin (Claude hook input JSON) and only
# enforces when an actual `git commit` or `git push` invocation is detected;
# all other commands pass through.
#
# When triggered, runs Biome (formatting + lint) then turbo typecheck on
# changed files vs main. Exits 2 to block the Bash tool call when either
# fails, so the agent gets the diagnostic back and can fix before CI rejects.
#
# Tools are run sequentially with short-circuit: if Biome fails, typecheck is
# skipped (the Biome diagnostic is enough to act on). Each tool's failure is
# reported separately so the agent knows which to fix.

set -u

# Parse the command out of the Claude hook input JSON.
cmd=$(jq -r '.tool_input.command // empty')

# Split on shell separators (; && || | &) and check each segment for a real
# git commit/push invocation. Handles env-var prefixes (FOO=bar, env FOO=bar)
# and git's top-level option flags (-C path, -c k=v, --no-pager, etc.) so
# `git -C path commit` and `GIT_AUTHOR_NAME=foo git commit` are caught, while
# quoted strings (`echo 'git commit later'`) and other git subcommands
# (`git checkout`, `git diff`) are not.
#
# On match, GIT_C_PATH holds the value passed to `-C` (empty when -C wasn't
# used) so the caller can scope the gate to the repo the command targets.
GIT_C_PATH=""
match_segment() {
  local seg="$1"
  GIT_C_PATH=""
  # shellcheck disable=SC2086
  set -- $seg
  # Skip leading env-var assignments (FOO=bar git ...)
  while [ $# -gt 0 ] && [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do shift; done
  # Skip optional `env` plus its own env assignments (env FOO=bar git ...)
  if [ "${1:-}" = "env" ]; then
    shift
    while [ $# -gt 0 ] && [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do shift; done
  fi
  # Must now start with literal `git`
  [ "${1:-}" = "git" ] || return 1
  shift
  # Skip git's top-level options between `git` and the subcommand,
  # capturing -C path so the gate can validate the target repo.
  while [ $# -gt 0 ]; do
    case "$1" in
      -C) GIT_C_PATH="${2:-}"; shift 2 ;;
      -c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env)
        shift 2 ;;
      --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--super-prefix=*|--config-env=*|--paginate|--no-pager|--no-replace-objects|--bare|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs)
        shift ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  case "${1:-}" in commit|push) return 0 ;; esac
  return 1
}

trigger=0
while IFS= read -r segment; do
  if match_segment "$segment"; then trigger=1; break; fi
done < <(echo "$cmd" | tr ';&|' '\n')

[ $trigger -eq 1 ] || exit 0

# Resolve the project root from CLAUDE_PROJECT_DIR (the env var Claude Code
# sets to the session's project directory). Falling back to `git rev-parse`
# from the hook's cwd is unreliable: if the agent's working directory is
# outside the repo (e.g. /tmp), rev-parse fails and own_root ends up empty,
# which both bypasses the `git -C` same-repo check and silently lets the
# commit proceed with the gate running from the wrong directory.
own_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$own_root" ] || [ ! -d "$own_root" ]; then
  # No way to locate the project — fail closed by blocking the commit. exit 2
  # is what Claude Code's PreToolUse contract uses to signal "block this tool
  # call"; exit 1 would silently allow it through.
  echo "Pre-commit gate could not resolve the project root (\$CLAUDE_PROJECT_DIR unset and not in a git repo)." >&2
  exit 2
fi
own_root=$(cd "$own_root" && git rev-parse --show-toplevel 2>/dev/null)

# If `git -C <path>` targets a different working tree from this project, skip:
# the gate's lint/typecheck pass is only meaningful for the repo it was set up
# in. Running it against an unrelated checkout would either block a foreign
# commit on Spree-specific lint or pass a check that doesn't apply.
if [ -n "$GIT_C_PATH" ]; then
  target_root=$(git -C "$GIT_C_PATH" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$target_root" ] && [ "$target_root" != "$own_root" ]; then
    exit 0
  fi
fi

cd "$own_root" || { echo "Pre-commit gate could not cd to $own_root" >&2; exit 2; }

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
