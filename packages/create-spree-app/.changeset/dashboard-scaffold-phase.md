---
'create-spree-app': minor
---

Offer the React Dashboard (Developer Preview) as an optional component: a new
prompt (and `--no-dashboard` flag) clones the dashboard starter into
`apps/dashboard/`, writes its `.env.local` (API URL only — never credentials),
installs dependencies, and wires the README, CLAUDE.md, and Dependabot config.
