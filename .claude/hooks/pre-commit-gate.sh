#!/usr/bin/env bash
# Pre-commit/push gate invoked by Claude Code's PreToolUse hook for every Bash
# tool call. Inspects the command on stdin (Claude hook input JSON) and only
# enforces when an actual `git commit` or `git push` invocation is detected;
# all other commands pass through.
#
# When triggered, runs RuboCop and Biome (formatting + lint) then turbo typecheck on
# changed files vs main. Exits 2 to block the Bash tool call when either
# fails, so the agent gets the diagnostic back and can fix before CI rejects.
#
# Tools are run sequentially with short-circuit: if Biome fails, typecheck is
# skipped (the Biome diagnostic is enough to act on). Each tool's failure is
# reported separately so the agent knows which to fix.

set -u

# Parse the command and its working directory out of the Claude hook input JSON.
input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
hook_cwd=$(jq -r '.cwd // empty' <<<"$input")

# Full test suites are queued machine-wide and are otherwise CI's job (see
# AGENTS.md "Testing"). Block the bare forms so a session that has not read the
# rule is redirected to the wrappers; targeted `rspec <paths>` runs pass.
while IFS= read -r segment; do
  seg="${segment#"${segment%%[![:space:]]*}"}"
  case " $seg " in *" pnpm test:rspec "*|*"scripts/test/rspec "*|*" pnpm wt:e2e"*|*"scripts/worktree/e2e.sh"*) continue ;; esac
  prefix='^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(env[[:space:]]+)?'
  if [[ "$seg" =~ ${prefix}(bundle[[:space:]]+exec[[:space:]]+|bin/)?parallel_rspec([[:space:]]|$) ]] \
     || [[ "$seg" =~ ${prefix}(bundle[[:space:]]+exec[[:space:]]+|bin/)?rspec([[:space:]]+spec/?)?[[:space:]]*$ ]] \
     || [[ "$seg" =~ ${prefix}pnpm[[:space:]]+(-[^[:space:]]+[[:space:]]+)*test:e2e([[:space:]]|$) ]]; then
    {
      echo "Blocked: $seg"
      echo "Full suites run one at a time on this machine and are CI's job. Use instead:"
      echo "  pnpm test:changed                    specs covering this branch's changed files"
      echo "  pnpm test:rspec <engine> [paths]     one engine; a full suite is queued, capped and low priority"
      echo "  pnpm wt:e2e [spec]                   Playwright, queued the same way"
      echo "Then push and watch CI for the full suite. If these commands are missing, run 'git merge main' first. See AGENTS.md, Testing."
    } >&2
    exit 2
  fi
done < <(echo "$cmd" | tr ';&|' '\n')

# Split on shell separators (; && || | &) and check each segment for a real
# git commit/push invocation. Handles env-var prefixes (FOO=bar, env FOO=bar)
# and git's top-level option flags (-C path, -c k=v, --no-pager, etc.) so
# `git -C path commit` and `GIT_AUTHOR_NAME=foo git commit` are caught, while
# quoted strings (`echo 'git commit later'`) and other git subcommands
# (`git checkout`, `git diff`) are not.
#
# GIT_SUB holds the git subcommand of any git segment, matched or not.
# On match, GIT_C_PATH holds the value passed to `-C` (empty when -C wasn't
# used) so the caller can scope the gate to the repo the command targets.
GIT_C_PATH=""
GIT_SUB=""

# Sets LAUNCHED to the segment without what runs in front of the real command:
# variable assignments (quoted values included), `env` with its options and
# assignments, `command` and `builtin`.
LAUNCHED=""
strip_launchers() {
  local s="$1" in_env=0 tok
  local assign="^[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|'[^']*'|[^[:space:]\"']*)+"
  while :; do
    s="${s#"${s%%[![:space:]]*}"}"
    if [[ "$s" =~ $assign ]]; then s="${s:${#BASH_REMATCH[0]}}"; continue; fi
    tok="${s%%[[:space:]]*}"
    case "$tok" in
      env) in_env=1 ;;
      command|builtin) ;;
      -u|-C|--unset|--chdir)
        [ $in_env -eq 1 ] || break
        s="${s#"$tok"}"; s="${s#"${s%%[![:space:]]*}"}"; tok="${s%%[[:space:]]*}" ;;
      -*) [ $in_env -eq 1 ] || break ;;
      *) break ;;
    esac
    s="${s#"$tok"}"
  done
  LAUNCHED="$s"
}

match_segment() {
  local seg="$1"
  GIT_C_PATH=""
  GIT_SUB=""
  strip_launchers "$seg"
  # shellcheck disable=SC2086
  set -- $LAUNCHED
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
  GIT_SUB="${1:-}"
  case "$GIT_SUB" in commit|push) return 0 ;; esac
  return 1
}

# Pull requests open through /open-pr, which runs /code-review and
# /security-review and then records the reviewed HEAD in the git dir. Block
# `gh pr create` until that marker matches the HEAD of the branch it opens, and
# that HEAD is the one pushed, so a commit made after the reviews sends the
# branch back through them. The check runs before the command does, so an
# earlier step in the same command that changes directory, moves HEAD or
# pushes is blocked rather than parsed.
pr_dir="${hook_cwd:-${CLAUDE_PROJECT_DIR:-.}}"
gh_pr_create='^gh([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+pr[[:space:]]+create([[:space:]);}]|$)'

# Sets HEAD_FLAG to the last `--head`/`-H` value in a command line, reading it
# the way gh's option parser does: quoted arguments are one word, a flag's
# value is never read as a flag, and short flags may be clustered (`-fH x`) or
# attached (`-Hx`, `-H=x`). Returns 1 when a quote is left open (the argument
# continues on a later line the gate cannot see) and 2 for a flag it does not
# know, since an unknown flag may take a value that hides a `--head`.
HEAD_FLAG=""
read_head_flag() {
  local s="$1" tok next="" rest char
  local word="^(\"[^\"]*\"|'[^']*'|[^[:space:]\"']+)+"
  local value_longs=" --assignee --base --body --body-file --label --milestone --project --reviewer --repo --title --template --recover "
  local switch_longs=" --draft --fill --fill-first --fill-verbose --web --editor --dry-run --no-maintainer-edit --help "
  HEAD_FLAG=""
  while s="${s#"${s%%[![:space:]]*}"}"; [ -n "$s" ]; do
    [[ "$s" =~ $word ]] || return 1
    tok="${BASH_REMATCH[0]}"
    s="${s:${#tok}}"
    tok="${tok//[\"\']/}"
    case "$next" in
      head) HEAD_FLAG="$tok"; next=""; continue ;;
      skip) next=""; continue ;;
    esac
    case "$tok" in
      --) return 0 ;;
      --head) next=head ;;
      --head=*) HEAD_FLAG="${tok#--head=}" ;;
      --*=*) [[ "$value_longs" == *" ${tok%%=*} "* ]] || return 2 ;;
      --*)
        if [[ "$value_longs" == *" $tok "* ]]; then next=skip
        elif [[ "$switch_longs" != *" $tok "* ]]; then return 2
        fi ;;
      -?*)
        rest="${tok#-}"
        while [ -n "$rest" ]; do
          char="${rest:0:1}"; rest="${rest:1}"
          case "$char" in
            [dfweh]) continue ;;
            H) rest="${rest#=}"; if [ -n "$rest" ]; then HEAD_FLAG="$rest"; else next=head; fi; break ;;
            [aBbFlmprRtT]) [ -n "$rest" ] || next=skip; break ;;
            *) return 2 ;;
          esac
        done ;;
    esac
  done
}

# A `--head` in any of gh's spellings, for text the gate could not parse.
gh_head_later='(^|[[:space:]])(--head|-[[:alpha:]]*H)'
chained=0
while IFS= read -r segment; do
  seg="${segment#"${segment%%[![:space:]({]*}"}"
  if match_segment "$seg" || [ -n "$GIT_SUB" ]; then
    case "$GIT_SUB" in status|log|diff|show|rev-parse|remote|branch) ;; *) chained=1 ;; esac
    continue
  fi
  if [[ "$LAUNCHED" =~ ^(cd|pushd|popd)([[:space:]]|$) ]]; then chained=1; continue; fi
  [[ "$LAUNCHED" =~ $gh_pr_create ]] || continue
  if [ $chained -eq 1 ]; then
    echo "Blocked: $seg" >&2
    echo "Run gh pr create as its own command: an earlier cd or git step in the same command changes what it would open." >&2
    exit 2
  fi
  # `--head <branch>` names what the pull request opens, so the gate checks the
  # worktree that has that branch checked out — a session started in another
  # checkout can still open it. Without `--head`, gh opens the current branch.
  # A multi-line argument hides whatever follows it, so a `--head` placed after
  # one cannot be read and the gate would check the wrong branch.
  read_head_flag "${LAUNCHED#*create}"
  case $? in
    2)
      echo "Blocked: $seg" >&2
      echo "The gate does not know one of these gh pr create flags, so it cannot tell which branch this opens. Use the long flag names --head, --title, --body-file." >&2
      exit 2 ;;
    1)
      if [[ "${cmd#*"$seg"}" =~ $gh_head_later ]]; then
        echo "Blocked: $seg" >&2
        echo "Put --head before any multi-line argument (or pass the body with --body-file) so the gate can read which branch this opens." >&2
        exit 2
      fi ;;
  esac
  # A backslash escapes a space (`Fix\ --head=x` is one argument) or continues
  # the line, and the gate reads neither the way the shell does.
  if [[ "$LAUNCHED" == *\\* ]]; then
    echo "Blocked: $seg" >&2
    echo "Keep gh pr create on one line without backslashes: quote arguments, or pass the body with --body-file." >&2
    exit 2
  fi
  review_dir="$pr_dir"
  head_owner=""
  if [ -n "$HEAD_FLAG" ]; then
    [[ "$HEAD_FLAG" == *:* ]] && head_owner="${HEAD_FLAG%%:*}"
    head_branch="${HEAD_FLAG##*:}"
    review_dir=$(git -C "$pr_dir" worktree list --porcelain 2>/dev/null | awk -v ref="refs/heads/$head_branch" '
      /^worktree / { path = substr($0, 10) }
      $0 == "branch " ref { print path; exit }')
    if [ -z "$review_dir" ]; then
      echo "Blocked: $seg" >&2
      echo "No worktree has $head_branch checked out, so the gate cannot tell whether it was reviewed. Run /open-pr from that branch." >&2
      exit 2
    fi
  else
    head_branch=$(git -C "$pr_dir" symbolic-ref --quiet --short HEAD 2>/dev/null)
  fi

  head=$(git -C "$review_dir" rev-parse HEAD 2>/dev/null)
  marker="$(git -C "$review_dir" rev-parse --absolute-git-dir 2>/dev/null)/claude-reviewed"
  if [ -z "$head" ] || [ "$(cat "$marker" 2>/dev/null)" != "$head" ]; then
    echo "Blocked: $seg" >&2
    echo "Open pull requests with /open-pr: /code-review and /security-review have not run on this HEAD. See AGENTS.md, Git." >&2
    exit 2
  fi

  # The pull request opens the remote branch of the same name, not the local
  # HEAD, so that must be the reviewed commit too. Read the remote-tracking ref
  # rather than `@{push}`: worktrees track origin/main, which `@{push}` either
  # cannot resolve or resolves to main.
  # Git's own order for where a branch pushes.
  push_remote=$(git -C "$review_dir" config "branch.$head_branch.pushRemote" \
    || git -C "$review_dir" config remote.pushDefault \
    || git -C "$review_dir" config "branch.$head_branch.remote" || echo origin)
  # `--head owner:branch` opens that owner's branch, so the push remote must be
  # the owner's repository, or the review checked someone else's branch.
  if [ -n "$head_owner" ]; then
    remote_url=$(git -C "$review_dir" remote get-url "$push_remote" 2>/dev/null)
    remote_owner=""
    # https://github.com/OWNER/…, git@github.com:OWNER/… or, over the HTTPS
    # port, ssh://git@ssh.github.com:443/OWNER/…
    github_owner='github\.com(:[0-9]+)?[:/]+([^/]+)/'
    [[ "$remote_url" =~ $github_owner ]] && remote_owner="${BASH_REMATCH[2]}"
    if [ -z "$remote_owner" ] || [ "$(tr '[:upper:]' '[:lower:]' <<<"$remote_owner")" != "$(tr '[:upper:]' '[:lower:]' <<<"$head_owner")" ]; then
      echo "Blocked: $seg" >&2
      echo "--head $HEAD_FLAG opens $head_owner's branch, but $head_branch pushes to ${remote_owner:-an unknown owner}. Drop the owner or push to that repository." >&2
      exit 2
    fi
  fi
  pushed=$(git -C "$review_dir" rev-parse --verify --quiet "refs/remotes/$push_remote/$head_branch" 2>/dev/null)
  if [ "$pushed" != "$head" ]; then
    echo "Blocked: $seg" >&2
    echo "Push the reviewed commit ($head) to $head_branch before opening the pull request." >&2
    exit 2
  fi
done < <(echo "$cmd" | tr ';&|' '\n')

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

# 1. RuboCop on the Ruby files this branch changed (exits 0 when there are none).
rubocop_out=$(scripts/lint/rubocop 2>&1)
rubocop_exit=$?

if [ $rubocop_exit -eq 3 ]; then
  echo "$rubocop_out" >&2
  echo "Install it, then retry: changed Ruby files must pass RuboCop before a commit or push." >&2
  exit 2
elif [ $rubocop_exit -ne 0 ]; then
  echo "RuboCop failed on changed Ruby files." >&2
  echo "" >&2
  echo "$rubocop_out" >&2
  echo "" >&2
  echo "Fix the lines listed above and leave the rest of each file alone. 'scripts/lint/rubocop --fix' autocorrects files that are new on this branch. Never add rubocop:disable comments." >&2
  exit 2
fi

# 2. Biome — fast (~1s), covers formatting + lint on changed files only.
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

# 3. Turbo typecheck — slower (1-9s depending on cache), runs tsc --noEmit
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
