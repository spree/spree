---
"@spree/core": patch
---

Adds the `PAYMENT_CAPTURE_EVENT_STATUSES` and `REFUND_STATUSES` enums (`requested`, `completed`, `failed`) with their types, and `requested` to the payment statuses, for payments whose provider answers a capture, void or refund later.
