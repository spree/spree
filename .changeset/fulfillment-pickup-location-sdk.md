---
"@spree/sdk": patch
---

`Fulfillment` now includes `pickup_location`: where the customer collects a pickup delivery. It is the counter chosen at checkout, which can differ from `stock_location` when the order ships there from a warehouse. It is `null` unless the delivery is a pickup.
