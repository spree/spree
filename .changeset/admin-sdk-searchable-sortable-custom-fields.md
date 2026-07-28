---
"@spree/admin-sdk": patch
---

Custom field definitions now support storefront search, sort, and filtering: `CustomFieldDefinition` exposes `searchable`, `sortable`, and `filter_key`, and create/update params accept `searchable` (short_text, long_text, number) and `sortable` (short_text, number). Product list requests accept the resulting `cf_*` keys as both `sort` values and Ransack filter predicates (e.g. `q[cf_custom_material_i_cont]`).
