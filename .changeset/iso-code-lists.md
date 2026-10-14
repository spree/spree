---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
---

Added `CountryCode`, `CurrencyCode` and `LocaleCode` as values as well as types, so you can write `CurrencyCode.USD`, list every code with `Object.values(CurrencyCode)` and see each code's name in your editor. Plain strings such as `'USD'` still type-check. Added `isCountryCode`, `isCurrencyCode` and `isLocaleCode` to check a value against the lists.
