---
"@spree/core": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
---

Typed the store's regional settings. The store's `default_country_code` is now `CountryCode`, its `admin_locale` is `LocaleCode` (send `null` to clear it), and its `timezone` — also on the seller profile — is the new `TimeZone` type, which suggests common IANA time zones while accepting any other. `TIME_ZONES` in `@spree/core` lists the suggested zones.
