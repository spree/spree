---
'create-spree-app': minor
---

Support the pnpm-native storefront template (spree/storefront now ships a `pnpm-lock.yaml` and pins pnpm via `packageManager`):

- Point the relocated storefront CI's `pnpm/action-setup` and setup-node dependency cache at `apps/storefront/` — both resolve from the repo root by default, where the storefront's package.json and lockfile don't exist in the generated layout, failing the workflow outright on pnpm scaffolds.
- Stamp `packageManager` into the generated root package.json on pnpm scaffolds (steers corepack, and doubles as the pnpm version fallback for root-run workflows); omitted for npm/yarn scaffolds.
- Install the cloned storefront with `--frozen-lockfile` under pnpm so template manifest/lockfile drift fails loudly instead of resolving silently to an untested tree.
- Default the generated README/CLAUDE.md command examples to pnpm, matching the package-manager detection default.
