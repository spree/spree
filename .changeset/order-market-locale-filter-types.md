---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
---

Order filter and sort types include `market_id` and `locale`. Locale, currency and country filters (`locale`, `currency`, `cost_currency`, `country_code`, `country_of_origin`) accept `LocaleCode`, `CurrencyCode` and `CountryCode` values instead of free text.
