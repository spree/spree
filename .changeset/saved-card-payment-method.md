---
"@spree/sdk": patch
"@spree/admin-sdk": patch
---

A saved card (`CreditCard`) now names the payment method it was saved with as `payment_method_id`, so a storefront offers it only for that method.
