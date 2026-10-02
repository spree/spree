---
"@spree/admin-sdk": minor
---

`orders.fulfillments.create` accepts an optional `source_fulfillment_id`, the only fulfillment to move units from. Without it, exchange and claim replacements are never moved, so naming the parcel is how a canceled replacement is sent again.
