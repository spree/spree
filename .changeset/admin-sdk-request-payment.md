---
"@spree/admin-sdk": minor
---

Added `orders.requestPayment`, which opens a draft order to its customer for payment on the storefront, and `orders.withdrawPaymentRequest`, which takes it back. Orders now carry `payment_requested_at`.
