---
"@spree/sdk": patch
---

`Refund` gains `store_credit_id`: the store credit a refund was paid as, or `null` when the money went back to the payment. Store credit given back for an order by a return, claim or exchange is now recorded as a refund against the order's payment.
