---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard-core": minor
"@spree/dashboard": minor
---

Gift cards can be sold as products. Products and variants carry `gift_card`, cart items accept an optional `recipient` (email, name, message, send date), and line items return the `recipient` and, once the order is paid, the `gift_cards` it issued with masked codes. The dashboard adds a gift card switch to the product form, an issued gift cards card to the order page and a gift card validity setting to the store settings.
