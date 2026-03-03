---
"@spree/next": patch
---

Add Markets data functions and update country types

- Add `listMarkets()`, `getMarket(id)`, `resolveMarket(country)`, `listMarketCountries(marketId)`, `getMarketCountry(marketId, iso)` data functions
- Export `StoreMarket` type
- **Breaking:** `StoreCountry` no longer includes `currency`, `default_locale`, `supported_locales` — use the markets API or `?include=market` on countries
