---
"@spree/next": minor
---

Replace market data functions with flat countries, currencies, and locales

- Remove `listMarkets`, `getMarket`, `resolveMarket`, `listMarketCountries`, `getMarketCountry`
- Add `listCountries`, `getCountry` — countries with currency and locale from markets
- Add `listCurrencies` — supported currencies
- Add `listLocales` — supported locales
- Export `StoreCurrency` and `StoreLocale` types, remove `StoreMarket`
