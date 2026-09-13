---
"@spree/dashboard-core": patch
---

Country pickers load the country list once per page and reuse it.

The list is reference data and does not change at runtime, so later address fields and country selects no longer call the API again.
