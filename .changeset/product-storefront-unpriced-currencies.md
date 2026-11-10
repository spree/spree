---
"@spree/admin-sdk": minor
---

Added `storefront_unpriced_currencies` to the Product type. Request it with `expand: ['storefront_unpriced_currencies']` to list the store currencies a product has no price in, which the storefront hides it from.
