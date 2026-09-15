---
'@spree/cli': minor
---

Added `spree config`: declarative store configuration from a YAML file.

- `spree config validate | diff | deploy | introspect` reconcile a `spree.config.yml` against any Spree instance through the Admin API. Records match on natural keys (code, slug, name, SKU), never on ids, so one file provisions a local project, staging and production.
- `deploy` creates and updates only; `--prune <sections>` allows deletes per section and `--fail-on-delete` refuses any delete, for CI. `--format json` on `diff` and `deploy` for machine-readable output.
- The engine ships as a library at `@spree/cli/config`, and the file's JSON Schema at `@spree/cli/schemas/spree-config.json`.
- `spree init` deploys the project's `spree.config.yml` after seeding with a key minted for that run, and no longer prompts for an admin account: the setup screen creates it and offers sample data. `--admin-email` / `--admin-password` remain for scripted installs, where `--no-sample-data` still applies.
