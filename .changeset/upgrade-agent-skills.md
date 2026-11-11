---
"@spree/cli": minor
---

`spree upgrade` now offers to update the Spree agent skills. When `skills-lock.json` lists skills from `spree/agent-skills`, it asks, then updates those skills from the main branch right after the `@spree/*` packages, for the agents they were installed for. A failed download only warns, now with the `skills` CLI's own reason, and `--yes` accepts the update.
