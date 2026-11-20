---
"@spree/sdk": patch
---

Types the new `payment.capture_requested`, `payment.capture_failed`, `payment.void_requested`, `payment.void_failed`, `refund.requested` and `refund.failed` webhook events. A saved card (`CreditCard`) names the payment method it was saved with as `payment_method_id`, so a storefront offers it only for that method.
