---
'@spree/cli': minor
'@spree/config': minor
---

Added `spree config`: declarative store configuration from a YAML file.

- `spree config validate | diff | deploy | introspect` reconcile a `spree.store.yml` against any Spree instance through the Admin API. Records match on natural keys (code, slug, name, SKU), never on ids, so one file provisions a local project, staging and production.
- `deploy` creates and updates only; `--prune <sections>` allows deletes per section and `--fail-on-delete` refuses any delete, for CI. `--format json` on `diff` and `deploy` for machine-readable output.
- The engine ships as its own package, `@spree/config` (browser-safe; `@spree/config/node` adds file loading), with the file's JSON Schema at `@spree/config/schemas/spree-config.json`.
- `spree init` deploys the project's `spree.store.yml` after seeding with a key minted for that run, and no longer prompts for an admin account: the setup screen creates it and offers sample data. `--admin-email` / `--admin-password` remain for scripted installs, where `--no-sample-data` still applies.
- `tax_rates` and `custom_field_definitions` sections, and `custom_fields` values on products, categories and sellers.
- `option_types`, `collections`, `companies`, `price_lists`, `catalogs` and `promotions` sections; `rules` on delivery methods; option types, categories and custom fields on product types.
- `spree sample-data` loads the demo store through the Admin API: a recipe of store files and CSV imports, exported from `@spree/config/sample-data`. `runRecipe`, `deployStep` and `importStep` build your own.
- Extensions add their own sections: list a module under `extensions:` in the file, and export a section made with `defineSection` from it.
