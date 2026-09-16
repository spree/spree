---
"@spree/cli": patch
---

Scaffold dashboards with the layout they grow into, and the packages their first import needs.

A new dashboard app shipped four files and no structure to follow, so the first customization had nowhere obvious to go. Both starters now carry the layout the dashboard uses internally — `pages/`, `hooks/`, `tables/`, `schemas/` and `locales/`, one file per resource — documented in the README, with an `AGENTS.md` covering the conventions a coding agent cannot infer.

They also gain `@spree/dashboard-core` and `@spree/dashboard-ui` as direct dependencies. Both were installed already but only as transitive ones, so under pnpm an import of either failed until you added it by hand.
