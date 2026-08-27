#!/usr/bin/env bash
# server-teardown.sh — remove the ./server/ development backend entirely:
# stop the Docker stack, wipe its volumes (database, bundle cache), and
# delete the server/ directory. Recreate from scratch with `pnpm server:setup`.
#
# Safe to run from any state — a missing stack or directory is a no-op.
# This is also the first phase of server-setup.sh (which passes --no-hint),
# so a partially-failed prior run never blocks a fresh one.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SERVER_DIR="$ROOT/server"

step() { printf '\n→ %s\n' "$1"; }

step "Tearing down the Docker stack (containers + volumes)"
# Reference the project by name (-p server) rather than via compose files,
# so this works even after a prior run deleted ./server/. Orphan volumes
# from a partially-failed run (server_bundle_cache, etc.) cause
# `failed to mkdir /var/lib/docker/volumes/.../ruby: file exists` on the
# next `up` if we don't wipe them here.
docker compose -p server down -v --remove-orphans 2>/dev/null || true

step "Removing $SERVER_DIR"
# Volumes are now released; bind-mounted files are accessible to rm again.
rm -rf "$SERVER_DIR"

if [ "${1:-}" != "--no-hint" ]; then
  printf '\nDone. Recreate from scratch with: pnpm server:setup\n'
fi
