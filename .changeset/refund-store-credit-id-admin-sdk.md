---
"@spree/admin-sdk": patch
---

`Refund` gains `store_credit_id`: the store credit a refund was paid as, or `null` when the money went back to the payment. Store credit given back for an order by a return, claim or exchange is now listed among the order's refunds, so `orders.refunds.list` and a payment's refunds include it.
