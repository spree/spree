---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
---

Request types that served both create and update are split by action, so creating marks what the API requires (a company's or tax rate's name, a tax registration's kind and value, an address's name, street, city and country) while updating takes any field. `AddressParams` and `CompanyAddressParams` in `@spree/sdk` stay as deprecated aliases until 6.1. The Admin SDK's `orders.payments.capture(orderId, id, params?, options?)` takes an optional `{ amount }` for a partial capture; request options move from the third argument to the fourth.

A tax exemption certificate's `issued_at`, `expires_at` and `verified_at` are typed `string | null`: a certificate that is still pending has no dates yet.
