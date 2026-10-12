---
"@spree/admin-sdk": patch
---

`orders.discounts.create()` takes the discount as `value` (with `value_type`); the older `amount` spelling on create is gone. `orders.discounts.update()` still edits `amount`.
