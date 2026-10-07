---
"@spree/admin-sdk": minor
---

Markets now carry `tax_display` (`included` or `dynamic`) and `default_country_code`, and accept both on create and update. `tax_display` sets what a market's prices mean for an order shipping outside the home country; `default_country_code` names the market's main country, which on the default market is the store's home country.
