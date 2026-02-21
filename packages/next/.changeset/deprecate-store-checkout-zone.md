---
'@spree/next': patch
---

Update `StoreStore` type — fields removed upstream in `@spree/sdk` (`default_currency`, `default_locale`, `default`, `supported_currencies`, `supported_locales`, `default_country_iso`) are no longer part of the store response. Use dedicated `listCurrencies`, `listLocales`, and `listCountries` functions instead.
