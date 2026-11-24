---
"@spree/dashboard": patch
---

A report grouped by a dimension that has no value for some group no longer fails to render. Discounts by coupon code is the common case: promotions applied without a code form a group with no code, which now shows with an empty label.
