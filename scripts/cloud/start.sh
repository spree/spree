#!/usr/bin/env bash
# Start the cloud session's servers in the background and wait until they
# answer. Already-running servers are left alone, so it is safe to re-run.
# Usage: scripts/cloud/start.sh [rails|dashboard|seller|all ...]  (default: rails dashboard)
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
root=$(pwd)

listening() { lsof -iTCP:"$1" -sTCP:LISTEN -n -P >/dev/null 2>&1; }

wait_for() {
  local name="$1" url="$2" log="$3"
  for _ in $(seq 1 180); do
    curl -fsS -o /dev/null "$url" 2>/dev/null && { echo "✓ $name  $url"; return 0; }
    sleep 1
  done
  echo "✗ $name did not answer at $url — last lines of $log:"
  tail -n 30 "$log"
  return 1
}

start_rails() {
  listening 3000 || (cd server && nohup bin/dev >/tmp/spree-rails.log 2>&1 &)
  wait_for "Rails" http://localhost:3000/up /tmp/spree-rails.log
}

# Vite ignores PORT, so build the shell's workspace deps first, then pin the port.
start_vite() {
  local name="$1" package="$2" port="$3" log="/tmp/spree-$1.log"
  if ! listening "$port"; then
    pnpm turbo build --filter="@spree/$package^..." >"$log" 2>&1
    (cd "$root/packages/$package" && nohup pnpm vite --port "$port" --strictPort >>"$log" 2>&1 &)
  fi
  wait_for "$name" "http://localhost:$port/" "$log"
}

targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=(rails dashboard)
[ "${targets[*]}" = all ] && targets=(rails dashboard seller)

for target in "${targets[@]}"; do
  case "$target" in
    rails) start_rails ;;
    dashboard) start_vite dashboard dashboard-starter 5173 ;;
    seller) start_vite seller seller-dashboard-starter 5175 ;;
    *) echo "Unknown target '$target' (rails, dashboard, seller, all)" >&2; exit 64 ;;
  esac
done
