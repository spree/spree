---
"@spree/dashboard": patch
---

`StoreSetupFields` takes its `countries` as `Country[]` from `@spree/admin-sdk`, the type `auth.setupCountries()` now returns, in place of the removed `SetupCountry`.
