---
"@spree/sdk": patch
---

`ProductFilterSortOption` now includes a `label` field — a human-readable name for custom-field-backed sort options (`cf_*` keys) returned by the product filters endpoint; `null` for built-in sort options.
