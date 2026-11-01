---
"@spree/admin-sdk": patch
"@spree/dashboard": patch
---

Admin API payments now return `can_void` and `can_capture`, which the payment method decides. The order page uses them to hide Void on captured payments that the gateway cannot void, such as Stripe. The dashboard no longer checks the payment status itself, so it needs a server that returns them.
