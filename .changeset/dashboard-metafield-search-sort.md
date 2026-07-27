---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Searchable and sortable custom fields now appear as first-class product table columns. Definitions can be marked searchable/sortable from the definition form, and the new `metafieldColumns` prop on `ResourceTable` merges them into the column selector, the Sort dropdown, and the filter panel — with operators matching each field type. `ColumnDef` gains an `expand` field so a visible column can declare the association the list request must expand.
