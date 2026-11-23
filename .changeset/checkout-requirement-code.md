---
"@spree/sdk": patch
---

`CheckoutRequirement` now includes `code`, the machine-readable requirement code the API returns (for example `order_minimum_not_met`). The type is now derived from the generated `Cart` type, so it can no longer drift from the API.
