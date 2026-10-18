---
"@spree/admin-sdk": patch
"@spree/dashboard": patch
---

`unit_cost` is now required on every purchase order item (`PurchaseOrderItemParams`), matching what the API already enforced. The dashboard's purchase order form now starts each line with an empty cost, so Save stays disabled until the merchant prices every line, instead of filling in zero.
