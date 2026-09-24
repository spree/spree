---
"@spree/admin-sdk": patch
---

`orders.refunds.create` no longer accepts `reason_id`. The Admin API only reads `refund_reason_id` (matching the `Refund` response field), so a `reason_id` was silently dropped and the refund fell back to the store's first refund reason. The params are now typed as `RefundCreateParams`; pass `refund_reason_id` instead.
