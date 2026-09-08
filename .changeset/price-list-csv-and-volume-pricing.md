---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard-ui": minor
"@spree/admin-sdk": minor
---

Volume pricing: quantity breaks, percentage tiers and a price-list CSV.

A price list can now carry a ladder per variant — a unit price from each
quantity up — edited as tier rows in the price spreadsheet, and a catalog's
percentage adjustment can step by quantity too. The catalog's price column
shows how many tiers a variant carries, with the ladder on hover and a note
that fixed tiers set the price regardless of the percentage.

A price list's prices can be exported and imported as CSV, one rung per row
keyed by SKU, from the list's own page and from the catalog that owns it.
The import merges: rows in the file are written, a blank price removes that
rung, and rungs the file does not mention are left alone. The admin SDK's
price, price list and import types carry the new fields, and the import
create call accepts the price list to merge into.
