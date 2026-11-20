---
"@spree/admin-sdk": patch
---

The Admin API types gain `Payment.requested_action`, `PaymentCaptureEvent.status`, `Refund.status` and `Refund.failure_reason`, with the `PaymentCaptureEventStatus` and `RefundStatus` types, and `PaymentStatus` gains `requested`. A saved card (`CreditCard`) names the payment method it was saved with as `payment_method_id`.
