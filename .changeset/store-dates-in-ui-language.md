---
"@spree/dashboard-core": patch
---

`formatStoreDateTime` and `formatStoreDate` now name months and order the date in the admin UI language, as the date pickers already do. Before, they always formatted in English, so a German or Polish dashboard showed English month names on refunds, seller transfers, digital links, publishing dates and price list schedules. The store timezone is still used.
