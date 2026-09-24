---
"@spree/sdk": minor
---

`carts.complete` is now typed as `Order | OrderGroup`: in a marketplace, a cart holding several sellers' goods completes into an order group rather than a single order. Added the `OrderGroup` type export and an `isOrderGroup` type guard so storefronts can tell the two apart.
