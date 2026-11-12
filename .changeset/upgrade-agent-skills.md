---
"@spree/cli": minor
---

`spree upgrade` now offers to update the Spree agent skills. When `skills-lock.json` lists skills from `spree/agent-skills`, it asks, then installs every skill from the main branch right after the `@spree/*` packages, so installed skills move to the newest version and new ones are added. A failed download only warns, now with the `skills` CLI's own reason, and `--yes` accepts the update.
