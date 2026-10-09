---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

List methods of documented endpoints now accept typed filter and sort parameters, generated from the filters each endpoint actually accepts; methods of endpoints the API reference does not document yet keep loose parameters. A misspelled filter, a filter the endpoint does not support, or an unknown sort field is now a type error instead of a request that silently returns the unfiltered list. `ProductListParams`, `CategoryListParams`, `CollectionListParams` and `OrderListParams` keep their names and are now generated; they no longer accept arbitrary keys. Filters an app adds through its own extensions are declared by extending `<Resource>FilterExtensions` (for example `ProductFilterExtensions`) with `declare module`.

The dashboard's allowed-origins search, delivery zones by profile, and several filters and sorts on payment methods, sellers, option types, markets, custom field definitions and gift cards now take effect; the API used to ignore them.
