---
"@spree/next": minor
---

Updated to use unified `carts` API from @spree/sdk 0.10.0

- All cart and checkout server actions now use explicit cart IDs via the `carts` namespace
- Added cart ID cookie storage (`getCartId`, `setCartId`, `clearCartId`)
- Cart ID is now persisted alongside the cart token for REST endpoint routing
- Exported `UpdateCartParams` type (replaces `UpdateCheckoutParams`)
