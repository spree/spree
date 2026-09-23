---
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
"@spree/sdk": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Returns can be refunded in more than one step. `ReturnStatus` gains `partially_refunded`, which a return keeps until everything it is owed has been refunded, and the dashboard and seller panel offer the refund action again on a partially refunded return.
