---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
---

Request body types are now generated from the API itself, so every create, update and action method takes exactly the fields its endpoint accepts. Fields the API never accepted are gone from the types, and fields it accepted but the types left out are added. Renamed types keep their old names as deprecated aliases (for example `VariantPrice` is now `PriceParams`, `LineItemInput` is now `LineItemInputParams`). The dashboard now saves the store's digital download limits, which the API used to drop.
