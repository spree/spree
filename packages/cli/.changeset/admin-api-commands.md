---
"@spree/cli": minor
---

New `spree api` and `spree auth` command groups — a generic Admin API client (`get`/`post`/`patch`/`delete`) built into the CLI:

- `spree api get|post|patch|delete <path>` — generic verbs with Ransack `-q` filters, `--sort`/`--page`/`--limit`/`--expand`/`--fields`, and JSON bodies from inline/`@file`/stdin
- `spree api endpoints` / `spree api schema` — offline schema introspection over a bundled OpenAPI snapshot, including each endpoint's required scope
- `spree api status` — resolved credentials + server reachability
- `spree auth login|status|logout|list` — named profiles in `~/.config/spree/config.json`
- `spree completion bash|zsh|fish` — shell completion for resource paths, Ransack predicate stems, and scope names, resolved offline from the bundled spec
- Zero-config credentials inside a project: a read-only key is minted via the dev stack on first use and stored in `.spree/credentials.json`. For other servers, `SPREE_API_KEY` is enough — the host defaults to `http://localhost:3000`; set `SPREE_BASE_URL` or save a profile for a remote store.

Output is JSON: indented and colored in a terminal, compact and uncolored when piped (clean for `jq`).

Works against any Spree 5.5+ instance.
