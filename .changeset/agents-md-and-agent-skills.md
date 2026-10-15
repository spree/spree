---
"create-spree-app": minor
"@spree/cli": patch
---

New projects now ask whether to install the Spree agent skills (default yes; `--agent-skills` / `--no-agent-skills` skip the question). The generated `AGENTS.md` is now the main instructions file for coding agents, with `CLAUDE.md` importing it, and it requires agents to run every command through the Spree CLI. `spree add dashboard` and `spree add seller-dashboard` now include a `CLAUDE.md` that imports the app's `AGENTS.md`, so Claude Code reads it too.
