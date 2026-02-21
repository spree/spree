---
"@spree/sdk": minor
---

Replace markets API with flat countries, currencies, and locales endpoints

- Remove `store.markets` (list, get, resolve, countries) methods
- Add `store.countries` (list, get) — each country includes `currency` and `default_locale` from its market
- Add `store.currencies` (list) — supported currencies derived from markets
- Add `store.locales` (list) — supported locales derived from markets
- Add `StoreCurrency` and `StoreLocale` types
- Update `StoreCountry` type with `currency` and `default_locale` fields
- Remove `StoreMarket` type
