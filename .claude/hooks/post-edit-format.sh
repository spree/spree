#!/usr/bin/env bash
# PostToolUse hook: auto-run Biome on the file Claude just edited.
#
# Reads the Claude Code hook input JSON from stdin, extracts the file_path,
# filters to TS/JS/JSON family extensions, then runs `biome check --write`.
# `--files-ignore-unknown=true` belt-and-suspenders for any extension that
# slips past the grep. `cd` to project root first so pnpm finds the workspace
# even when the agent is operating from a subdir or outside the repo.
#
# Always exits 0 — formatting failures should never block a file edit; the
# pre-commit gate is the real enforcement layer.

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" 2>/dev/null || exit 0

file_path=$(jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

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
