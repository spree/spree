---
"@spree/cli": minor
"create-spree-app": minor
---

New projects now depend on `@spree/docs` on the Spree major (`^6.0.0-0`) instead of `latest`, since the docs package now carries the Spree version: `@spree/docs@6.0.4` documents Spree 6.0.4. `spree upgrade` moves it with the server like the dashboard packages, and rewrites the `latest` spec of older projects to the server's version.

`spree add ai` and `spree upgrade` now install the Spree agent skills from the `spree/agent-skills` release tagged for the Spree version (the newest tag on its minor line that is not newer), instead of the main branch. `skills-lock.json` records that release. When the line has no release yet, the skills still come from the main branch.

New projects' `AGENTS.md` describes the local docs and the skills as matched to the project's Spree version, and no longer recommends the deprecated `spree rspec`, `spree routes`, `spree rails` and `spree rake` commands.
