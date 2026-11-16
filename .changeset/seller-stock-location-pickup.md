---
"@spree/seller-sdk": patch
"@spree/dashboard-core": patch
---

Editing a stock location in the seller panel no longer turns customer pickup off. The Seller API left a location's pickup setting, pickup stock policy, internal name, backorderable default and "propagate all variants" setting out of its responses, so the form opened with them off and saved them back off. Seller stock locations now return these fields, and `@spree/seller-sdk`'s `StockLocation` type includes them.
