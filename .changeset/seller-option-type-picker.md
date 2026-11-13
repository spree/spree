---
"@spree/seller-sdk": minor
"@spree/seller-dashboard": minor
"@spree/dashboard-core": patch
---

Sellers can build variants from the marketplace's existing option types and values. The seller SDK gains a read-only `optionTypes.list` / `get`, and the seller dashboard registers it so the shared variant options builder offers a picker without any way to create option types or values.
