---
'@spree/sdk': patch
---

Expose `Product.option_values` in the Store API.

The `Product` type now includes an optional `option_values: Array<OptionValue>` field, listing the option values that are actually in use across the product's variants. This lets storefronts render option pickers (size, color, etc.) without iterating over every variant to collect them.
