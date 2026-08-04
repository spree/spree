---
'@spree/sdk': major
---

Spree 6.0 Store API line. Breaking changes for storefront integrations:

- Completed carts are no longer served by the cart endpoints — fetching one returns 404, the signal to drop stale cart state. The checkout outcome stays reachable through `orders.get(cartId)` authorized by the cart token (the order inherits it).
- `DeliveryZone.members` is only embedded when requested with `expand=members` (the type is now optional).
- The placement webhook event is `order.placed`; `order.completed` is still dual-emitted through 6.0 with `deprecated_alias_of` metadata and drops in 6.1.

Additions: `coupon_code` on Cart and Order (with pending-code semantics — a real but not-yet-eligible code is kept and applies once the cart qualifies), `cart_id` on Order for matching cart activity to its conversion, and `cart.created` / `cart.updated` / `cart.deleted` webhook events for abandonment tooling.
