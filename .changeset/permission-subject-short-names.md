---
"@spree/dashboard": minor
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
---

Changed permission subjects to short names: `/me` returns `product`, `category`, `customer` instead of Ruby class names, and the `Subject` constants, `<Can>` checks and navigation `subject` entries use the same names. Plugins that pass class names (`'Spree::Order'`) to `permissions.can`, `<Can>` or a navigation entry must switch to the short name (`'order'`) or a `Subject` constant. Category checks now work for roles without full access.
