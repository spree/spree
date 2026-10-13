---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
---

Country and currency names move to the client: the Store API's country `name` and currency `name` and `symbol` are deprecated (name them with `Intl.DisplayNames`, format amounts with `formatMoney`), and the Admin and Seller APIs no longer return a country's `name`. The seller SDK's `SellerCountry` is now the generated `Country` type, and the setup country list's `locales` are typed as `LocaleCode[]`. The dashboard and seller panel name and sort countries in the admin's own language.
