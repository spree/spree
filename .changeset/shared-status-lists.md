---
"@spree/core": minor
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/seller-dashboard": patch
---

Added every status, kind and other value list the Spree API returns to `@spree/core`, each as a list of its values (`PRODUCT_STATUSES`, `MEDIA_TYPES`, …) and a type (`ProductStatus`, `MediaType`, …) — open where extensions may add values, closed otherwise — plus `subsetOf` for picking the values an action accepts with each one checked at compile time. The SDKs re-export these types instead of each carrying its own copy, so their names and values are unchanged. The dashboards and the seller panel build their status filters and action checks from these lists, so a status added on the server shows up without a dashboard change. Value lists the SDKs used to spell out inline, such as a seller transfer's `kind`, now have names of their own; `MediaType` and `CollectionRuleMatchPolicy` in `@spree/admin-sdk` now come from the generated types under the same names.
