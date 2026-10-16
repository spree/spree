---
"@spree/admin-sdk": minor
---

Tax rates no longer have `included_in_price`, in responses, create and update params, filters or sort. Whether prices include tax is now the market's `tax_inclusive` setting.
