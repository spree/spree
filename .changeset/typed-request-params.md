---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
---

Request body types are now generated from the API itself, so every create, update and action method takes exactly the fields its endpoint accepts. Fields the API never accepted are gone from the types, and fields it accepted but the types left out are added. Renamed types keep their old names as deprecated aliases (for example `VariantPrice` is now `PriceParams`, `LineItemInput` is now `LineItemInputParams`). The dashboard now saves the store's digital download limits, which the API used to drop.

Country and currency codes are typed as the closed `CountryCode` and `CurrencyCode` unions in both requests and responses. Deprecated fields are marked `@deprecated` in the types; the Store SDK keeps them until 6.1, while the Admin and Seller SDKs drop them (address `country_iso`/`state_abbr`, cart `number`, market `country_isos`, import `owner_type`/`owner_id`, payment method `auto_capture`).
