---
"@spree/cli": minor
---

New `spree api` and `spree auth` command groups — a gh api-style Admin API client built into the CLI:

- `spree api get|post|patch|delete <path>` — generic verbs with Ransack `-q` filters, `--sort`/`--page`/`--limit`/`--expand`/`--fields`, and JSON bodies from inline/`@file`/stdin
- `spree api endpoints` / `spree api schema` — offline schema introspection over a bundled OpenAPI snapshot, including each endpoint's required scope
- `spree api status` — resolved credentials + server reachability
- `spree auth login|status|logout|list` — named profiles in `~/.config/spree/config.json`
- Zero-config credentials inside a project: a read-only key is minted via the dev stack on first use and stored in `.spree/credentials.json`; remote stores use profiles or `SPREE_BASE_URL`/`SPREE_API_KEY`

Works against any Spree 5.5+ instance.
