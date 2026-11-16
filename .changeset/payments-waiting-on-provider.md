---
"@spree/dashboard": patch
"@spree/admin-sdk": patch
"@spree/sdk": patch
"@spree/seller-sdk": patch
"@spree/core": patch
---

A payment whose provider accepted a capture or void and has not answered yet shows as "Capture requested" or "Void requested", with no payment actions until the provider answers. A payment's details list its refunds with each one's status and, for a failed refund, the provider's reason. The Admin API types gain `Payment.requested_action`, `PaymentCaptureEvent.status`, `Refund.status` and `Refund.failure_reason`, `PaymentStatus` gains `requested`, and `@spree/sdk` types the new `payment.capture_requested`, `payment.capture_failed`, `payment.void_requested`, `payment.void_failed`, `refund.requested` and `refund.failed` webhook events.
