---
"@spree/sdk": patch
---

Add Markets API support and simplify Country type

- Add `StoreMarket` type with `id`, `name`, `currency`, `default_locale`, `supported_locales`, `tax_inclusive`, `default`, and optional `countries`
- Add `client.store.markets` with `list()`, `get(id)`, `resolve(country)`, and nested `countries.list(marketId)` / `countries.get(marketId, iso)`
- **Breaking:** Remove `currency`, `default_locale`, `supported_locales` from `StoreCountry` — these now live on `StoreMarket`. Use `?include=market` on the countries endpoint or the markets endpoint directly
- Add optional `market?: StoreMarket` field to `StoreCountry` (populated when `?include=market` is passed)
