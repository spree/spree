---
"@spree/admin-sdk": patch
"@spree/dashboard": patch
---

Admin API payments now return `can_void` and `can_capture`, which the payment method decides. The order page uses them to hide Void on captured payments that the gateway cannot void, such as Stripe. Older servers that do not send them keep the previous status-based rule.
