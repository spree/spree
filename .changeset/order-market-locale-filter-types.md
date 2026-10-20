---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
---

Order filter and sort types include `market_id` and `locale`. Locale, currency and country filters (`locale`, `currency`, `cost_currency`, `country_code`, `country_of_origin`) accept only `LocaleCode`, `CurrencyCode` and `CountryCode` values (new `CodeFilters` type) instead of free text.
