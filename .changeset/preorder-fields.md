---
"@spree/sdk": minor
---

Surface pre-order status on the Store API types. `Variant`, `Product`, and `LineItem` now expose `preorder` (whether the item is currently sold as a pre-order) and `preorder_ships_at` (the customer-facing "ships by" promise, `null` unless it's a live pre-order), so storefronts can render a "Pre-order — ships by …" badge. Both fields are included in the generated Zod schemas.
