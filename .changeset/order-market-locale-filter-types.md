---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
---

Order filter and sort types include `market_id` and `locale`. Locale filters (`locale`, `default_locale`) accept `LocaleCode` values instead of free text.
