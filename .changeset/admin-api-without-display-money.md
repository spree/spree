---
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard-ui": minor
"@spree/seller-dashboard": minor
---

The Admin and Seller APIs no longer return `display_*` money fields, so their types drop them; format the amount with its currency instead. The dashboard and seller panel format every amount in the admin's own language. `formatMoney` writes a currency's ISO 4217 decimals and takes `{ unitPrice: true }` for up to four.
