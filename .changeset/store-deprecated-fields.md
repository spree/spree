---
"@spree/sdk": patch
---

Stock locations bring back `country_iso` and `state_abbr`, and refunds bring back `reimbursement_id` (always `null`), all marked `@deprecated` until 6.1 so a 5.6 storefront keeps compiling. `AppliedPromotion`, `Fee`, `TaxLine` and `Delivery`, which carts, orders and their items already carry, are now exported from the package root.
