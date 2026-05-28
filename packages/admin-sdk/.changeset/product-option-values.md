---
'@spree/admin-sdk': patch
---

Expose `Product.option_values` in the Admin API.

The `Product` type now includes an optional `option_values: Array<OptionValue>` field, listing the option values that are actually in use across the product's variants — useful for rendering option pickers and variant matrices in the admin without iterating over every variant.
