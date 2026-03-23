---
"@spree/next": minor
---

**Breaking:** Removed `getFulfillments()` server action — fulfillments are included in the cart response. Use `cart.fulfillments` instead.

**New:** Added `listStoreCredits()` server action and `StoreCredit` type re-export.

Requires `@spree/sdk` >= 0.12.0.
