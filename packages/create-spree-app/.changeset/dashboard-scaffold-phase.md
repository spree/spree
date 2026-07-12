---
'create-spree-app': minor
---

Offer the React Dashboard (Developer Preview) as an optional component: a new
prompt (and `--no-dashboard` flag) scaffolds it into `apps/dashboard/` by
delegating to the project-local `npx spree add dashboard` (the CLI bundles the
starter template with version pins matching its release), and wires the
README, CLAUDE.md, and Dependabot config.
