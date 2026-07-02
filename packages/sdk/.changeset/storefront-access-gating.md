---
"@spree/sdk": minor
---

Support gated storefronts in the Store API. A channel (or its store) can now hide prices from anonymous visitors or require a login to browse: when prices are hidden, monetary fields on products, carts, and orders return `null` for guests, and `login_required` channels reject unauthenticated requests with `401`. Guest checkout can likewise be disallowed per channel, in which case completing a cart without a signed-in customer returns `401`.
