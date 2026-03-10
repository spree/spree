---
"@spree/next": patch
---

Renamed Taxons/Taxonomies to Categories. `listTaxons`/`getTaxon`/`listTaxonProducts` replaced with `listCategories`/`getCategory`/`listCategoryProducts`. `listTaxonomies`/`getTaxonomy` removed. Re-exported `Category` type replaces `Taxon`/`Taxonomy`.
