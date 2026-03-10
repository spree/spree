---
"@spree/sdk": patch
---

Renamed Taxons/Taxonomies to Categories in the public API surface. `client.taxons` is now `client.categories`, `client.taxonomies` has been removed. Types `Taxon`/`Taxonomy` replaced with `Category`. Filter types updated accordingly (`TaxonFilter` → `CategoryFilter`, `TaxonListParams` → `CategoryListParams`, `ProductFiltersParams.taxon_id` → `category_id`).
