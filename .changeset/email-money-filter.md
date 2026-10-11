---
"@spree/dashboard": patch
"@spree/admin-sdk": patch
---

The email template editor inserts an amount through the `money` filter (`{{ order.total | money }}`) instead of a pre-formatted `display_*` field. Email types gain the raw amounts the default templates now format: `total_minus_store_credits`, a line item's and a parcel item's `amount`, a parcel item's `price`, a fulfillment group's `cost` and `unpriced`, and a return's `refunded_total`.
