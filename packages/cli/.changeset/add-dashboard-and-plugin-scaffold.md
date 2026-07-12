---
'@spree/cli': minor
---

Add `spree add dashboard` — scaffolds the React Dashboard starter (Developer
Preview), bundled inside the CLI with version pins matching the release, into
`apps/dashboard/` of an existing project and points it at the project's API
(`--template <path|git-url>` overrides the bundled copy). Also make
`spree plugin new` fully non-interactive: every prompt has a flag
(`--ruby-name`, `--module-name`, `--npm-scope`, `--author`, `--author-email`,
`--license`, `-y`), with author details defaulting from git config.
