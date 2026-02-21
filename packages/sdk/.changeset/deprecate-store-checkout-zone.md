---
'@spree/sdk': minor
---

Remove deprecated fields from `StoreStore` type — these are now managed through Markets and dedicated API endpoints

- Remove `default_currency` — use `store.currencies.list()` or the `X-Spree-Country` header for automatic currency resolution
- Remove `default_locale` — use `store.locales.list()` or the `X-Spree-Country` header for automatic locale resolution
- Remove `default` — internal flag, not useful for storefront clients
- Remove `supported_currencies` — use `store.currencies.list()` instead
- Remove `supported_locales` — use `store.locales.list()` instead
- Remove `default_country_iso` — use `store.countries.list()` instead
