---
'@spree/cli': minor
'@spree/seeds': minor
---

`spree seed` now seeds a store from a file.

- Inside a project, `spree seed` runs the database seeds and then deploys `spree.seeds.yml` through the Admin API. With `--base-url` or `--profile` it deploys the file to that instance. Records match on natural keys (code, slug, name, SKU), never on ids, so one file seeds a local project, staging and production.
- `--dry-run` shows what would change. A deploy creates and updates only; `--prune <sections>` allows deletes per section and `--fail-on-delete` refuses any delete, for CI. `--format json` for machine-readable output.
- `spree seed validate` checks the file offline, `spree seed introspect` writes a live store to a file, and `spree seed defaults` creates the defaults a new store starts with.
- The engine ships as its own package, `@spree/seeds` (browser-safe; `@spree/seeds/node` adds file loading), with the file's JSON Schema at `@spree/seeds/schemas/spree-seeds.json`.
- `spree init` deploys the project's `spree.seeds.yml` after seeding with a key minted for that run, and no longer prompts for an admin account: the setup screen creates it and offers sample data. `--admin-email` / `--admin-password` remain for scripted installs, where `--no-sample-data` still applies.
- Sections cover settings, delivery, tax, payments, catalog (option types, product types, categories, products, collections), customers and B2B (companies, price lists, catalogs), promotions, sellers, and custom field definitions and values.
