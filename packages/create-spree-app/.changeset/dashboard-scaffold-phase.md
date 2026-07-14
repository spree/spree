---
'create-spree-app': minor
---

Offer the React Dashboard (Developer Preview) as an optional component: a new
prompt (and `--no-dashboard` flag) scaffolds it into `apps/dashboard/` by
delegating to the project-local `spree add dashboard` (the CLI bundles the
starter template with version pins matching its release), and wires the
README, CLAUDE.md, and Dependabot config.

New projects now default to **pnpm** when it's installed — it's what the
Spree packages and docs are built around. An explicit invoking agent
(`pnpm create spree-app`, `yarn create spree-app`) and the
`--use-npm`/`--use-yarn`/`--use-pnpm` flags still win, and npm remains the
fallback when pnpm is absent. The generated README, CLAUDE.md, and next-steps
output now render commands for the chosen package manager instead of
hardcoding npm.
