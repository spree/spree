---
"@spree/dashboard": patch
---

The import and export buttons now pass the API type shorthand (`"products"`, `"customers"`, `"orders"`, `"coupon_codes"`) instead of the Ruby class name, and the import wizard reads the shorthand the API returns. Values in the older `Spree::Imports::Products` form are still understood, so an import opened from a cached payload keeps rendering its type and "view records" link correctly.
