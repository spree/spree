---
"@spree/admin-sdk": minor
---

Add pre-order management to the Admin API. `Variant` now exposes the editable `preorderable` flag, `preorder_ships_at` (the "ships by" date), and `backorder_limit` (the universal oversell cap — units sellable beyond available stock as backorders or pre-orders; `null` = unlimited), alongside the computed `preorder` state; `Product` and `LineItem` gain `preorder` + `preorder_ships_at`. `ProductVariantInput`, `VariantCreateParams`, and `VariantUpdateParams` accept `preorderable`, `preorder_ships_at`, and `backorder_limit`, so a variant can be flagged for pre-order and capped in a single write.
