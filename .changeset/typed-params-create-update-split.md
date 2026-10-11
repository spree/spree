---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
---

Request types that served both create and update are split by action, so creating marks what the API requires (a company's or tax rate's name, a tax registration's kind and value, an address's name, street, city and country) while updating takes any field. `AddressParams` and `CompanyAddressParams` in `@spree/sdk` stay as deprecated aliases until 6.1. The Admin SDK's `orders.payments.capture()` takes an optional `{ amount }` for a partial capture.
