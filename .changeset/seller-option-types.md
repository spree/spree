---
"@spree/seller-sdk": patch
"@spree/seller-dashboard": patch
"@spree/dashboard-core": patch
---

Sellers can now build variants from the option types the marketplace defines. The seller panel's product form offered no option types at all, so a seller could never add a variant with a size or colour. The Variants card now lists the marketplace's option types and their values to pick from, and picking a product type on a new listing offers its option types there, as the operator's form does. A seller still cannot add an option type or a value; that stays with the marketplace. The Seller API now enforces this too: a product or variant written through `/api/v3/seller/products`, or a row of a seller's CSV import, that names an option type or value the store does not already have is refused (a 422 naming `variants`, or a failed row) instead of quietly creating it. The operator's API and imports still create missing option types and values as before.

`@spree/seller-sdk` gains `client.optionTypes.list()` and `client.optionTypes.get()` for the new read-only `GET /api/v3/seller/option_types` endpoint. Pass `expand: ['option_values']` for the values. Product types now carry `option_type_ids` next to `option_type_labels`.

The product form now fetches a product type's option types by id, so a type naming option types past the first 100 still offers them in Variants, in both panels.
