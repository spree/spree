---
"@spree/cli": minor
---

`spree upgrade` now offers to update the Spree agent skills. When the project has them in `.agents/skills/`, it asks, then installs the latest skills from the main branch of `spree/agent-skills` right after the `@spree/*` packages. A failed download only warns, and `--yes` accepts the update.
