---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
"@spree/dashboard": patch
---

Weight and dimension units are closed code lists, exported as `WeightUnit` and `DimensionUnit` (values and types) like `CountryCode` and `CurrencyCode`, and every unit field in responses and request types uses them; unit fields in requests accept `null` to fall back to the store default. The Admin and Seller SDKs publish one `VariantParams` type: `ProductVariantParams`, `VariantCreateParams` and `VariantUpdateParams` build on it. The Seller SDK's `SellerProductVariantParams` is renamed to `ProductVariantParams` (the old name stays as a deprecated alias). The variant editor and bulk variant editor now offer feet as a dimension unit.
