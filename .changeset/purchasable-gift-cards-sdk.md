---
"@spree/sdk": minor
---

Gift cards can be sold as products. `Product` and `Variant` carry `gift_card`. Adding or updating a cart item accepts an optional `recipient` (email, name, message, send date). Line items return that `recipient` and, once the order is paid, the `gift_cards` it issued, with masked codes. Adds the `GiftCardIssuedEvent` webhook type for `gift_card.issued`.
