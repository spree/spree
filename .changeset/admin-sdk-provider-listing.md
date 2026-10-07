---
"@spree/admin-sdk": minor
---

Payment methods, payment method types and integration types now carry `logo_url` and `docs_url`, the provider's logo and setup guide. Payment methods and their types also carry `third_party`, true for methods backed by an external payment provider. `PaymentMethodType` is its own interface rather than an alias of `ResourceTypeDefinition`.
