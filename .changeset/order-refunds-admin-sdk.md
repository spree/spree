---
"@spree/admin-sdk": patch
---

The `Order` type has `refunds_total` and an optional `refunds` list, returned by the Admin API when the order is requested with `?expand=refunds`. The `Refund` type has `refund_reason_name`.
