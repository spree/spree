---
'@spree/seeds': minor
---

Added `@spree/seeds`, the engine that plans and deploys a `spree.seeds.yml` through the Admin API.

- Browser-safe; `@spree/seeds/node` adds file loading. The file's JSON Schema ships at `@spree/seeds/schemas/spree-seeds.json`.
- Records match on natural keys (code, slug, name, SKU), never on ids. A deploy creates and updates only; deletes are opt-in per section.
- Sections cover settings, delivery, tax, payments, catalog (option types, product types, categories, products, collections), customers and B2B (companies, price lists, catalogs), promotions, sellers, and custom field definitions and values.
- Also holds the defaults every new store starts with, deployed by `provisionStore`.
