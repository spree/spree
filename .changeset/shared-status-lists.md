---
"@spree/core": minor
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
---

Added every status and kind the Spree API returns to `@spree/core`, each as a list of its built-in values (`PRODUCT_STATUSES`, `FEE_KINDS`, …) and an open type (`ProductStatus`, `FeeKind`, …), plus `subsetOf` for picking the values an action accepts with each one checked at compile time. The SDKs re-export these types instead of each carrying its own copy, so their names and values are unchanged. The dashboards and the seller panel build their status filters and action checks from these lists, so a status added on the server shows up without a dashboard change.
