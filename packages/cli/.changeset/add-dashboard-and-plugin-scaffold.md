---
'@spree/cli': minor
---

Add `spree add dashboard` — clones the React Dashboard starter (Developer
Preview) into `apps/dashboard/` of an existing project and points it at the
project's API. Also make `spree plugin new` fully non-interactive: every prompt
has a flag (`--ruby-name`, `--module-name`, `--npm-scope`, `--author`,
`--author-email`, `--license`, `-y`), with author details defaulting from git
config.
