#!/usr/bin/env bash
# PostToolUse hook: auto-format the file Claude just edited.
#
# Reads the Claude Code hook input JSON from stdin and extracts the file_path.
# Ruby files go through RuboCop (scripts/lint/rubocop --fix); TS/JS/JSON
# family files through `biome check --write`. `--files-ignore-unknown=true`
# belt-and-suspenders for any extension that slips past the filter. `cd` to
# project root first so pnpm finds the workspace even when the agent is
# operating from a subdir or outside the repo.
#
# Never blocks an edit. Biome always exits 0; RuboCop exits 2 only to report
# offenses it could not fix. The pre-commit gate is the real enforcement layer.

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" 2>/dev/null || exit 0

file_path=$(jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

# Ruby: apply RuboCop's safe fixes, then hand what is left back to Claude
# (exit 2 on PostToolUse shows stderr to the model without undoing the edit).
# A missing bundle is left to the pre-commit gate.
case "$file_path" in
  *.rb|*.rake|*.gemspec|*Gemfile|*Rakefile)
    rubocop_out=$(scripts/lint/rubocop --fix "$file_path" 2>&1)
    if [ $? -eq 1 ]; then
      echo "RuboCop offenses remain in $file_path (safe ones were fixed). Fix these now:" >&2
      echo "$rubocop_out" | grep -v '\[Corrected\]' >&2
      exit 2
    fi
    exit 0 ;;
esac

# Filter to extensions Biome formats.
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.mts|*.cts|*.json|*.jsonc) ;;
  *) exit 0 ;;
esac

# Pass the path as a single argv element via "$file_path" — no word-splitting,
# spaces and special chars in the path are preserved.
pnpm exec biome check --write \
  --no-errors-on-unmatched \
  --files-ignore-unknown=true \
  --reporter=summary \
  "$file_path" >&2 || true

exit 0
