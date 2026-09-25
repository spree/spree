---
"@spree/sdk": patch
---

Document that store credit is applied with `carts.storeCredits.apply()`, not `carts.payments.create()`.

Store credit is a non-session payment method, so reaching for `payments.create()` was the natural mistake — and it failed with "Source can't be blank". That endpoint now answers with a `store_credits_endpoint_required` error naming the right one.
