---
"@spree/sdk": minor
---

Added `orders.complete` and `orders.paymentSessions` for paying a draft order the merchant raised for the customer. `orders.get` also returns such a draft, with the `payment_methods` it can be paid with.
