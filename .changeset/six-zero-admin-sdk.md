---
'@spree/admin-sdk': patch
'@spree/cli': patch
---

Admin API additions from the 6.0 core rewrite:

- `deliveryMethods.rules` CRUD and `deliveryMethods.ruleTypes()` — delivery method eligibility rules (item total, weight).
- `orders.discountCodes.create/delete` — apply and remove coupon codes on draft orders with the storefront's pending semantics.
- `expand=cart` on orders returns the originating cart (new admin `Cart` type); the embedded promotion summaries moved from the `discounts` key to `applied_promotions` (the `discounts` name stays reserved for the typed money rows at `/orders/:id/discounts`).
- Delivery methods accept `stock_location_ids` for pickup; delivery zones, delivery methods and stock locations are store-scoped.
- `Order` gains `cart_id` and `coupon_code`; `DeliveryZone.members` requires `expand=members`.
