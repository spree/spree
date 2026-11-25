---
"@spree/admin-sdk": patch
---

`PaymentFilters` now accepts `requested` for `status_eq`, `status_in` and the other status filters, so you can list payments waiting for the payment provider to confirm a capture or void.

`CreditCardFilters` and `CreditCardSort` now accept `payment_method_id`, so you can list a customer's saved cards for one payment method.
