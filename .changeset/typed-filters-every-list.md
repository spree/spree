---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
---

Every filterable list method now takes typed filter and sort parameters, including returns, claims, exchanges, custom fields, digital links, payouts, imports and the rest that still accepted any key. The building block for custom field value filters is now `CustomFieldValueFilters`, so it no longer hides the generated filters for custom field lists. The product digital files list now pages by 25 as intended.
