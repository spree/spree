---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/core": minor
"@spree/dashboard": minor
---

Businesses can register a company from the storefront, and stores can show prices only to company members.

- `@spree/sdk`: `client.companies.create({ name, registration })` registers a company and makes the signed-in customer its first member. Products, variants, carts, orders and line items carry `pricing_access`, which says why their prices are `null`: `login_required`, `company_required`, or a code an extension adds.
- `@spree/core`: `storefront_access` gains `company_required`, and the new `PricingAccess` type lists the built-in `pricing_access` codes.
- `@spree/admin-sdk`: channel and store `storefront_access` accept `company_required`.
- `@spree/dashboard`: channel and store settings offer the "Company members only" storefront access option.
