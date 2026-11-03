---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
---

Added what a storefront needs for a self-service returns portal. Orders carry `returns_eligibility`, and each fulfillment item lists its shipped `units` with what the customer may still send back and why not. Products, variants and line items carry `returnable`. The Store SDK adds `orders.exchanges`, `orders.returns.cancel`, `returnReasons.list`, `claimReasons.list` and `orderLookups.create`. Returns and exchanges now include the customer's `memo` and whether they are `cancelable`, and returns say whether a label is waiting and where the parcel is.
