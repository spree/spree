---
"@spree/admin-sdk": minor
---

`orders.fulfillments.create` now accepts an optional `cost` (explicit shipping cost, e.g. the 3PL price — frozen exactly on `status: 'shipped'` registrations; note it changes the order total and payment state). When `delivery_method_id` is omitted, the new fulfillment now inherits the delivery method and cost of the source fulfillment(s) it fully drains instead of defaulting to the lowest-cost rate.
