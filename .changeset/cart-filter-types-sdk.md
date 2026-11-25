---
"@spree/sdk": patch
---

Added the `CartFilters` and `CartSort` types for the filters and sort fields `GET /carts` accepts: `email`, `token`, `id`, `completed_at`, `created_at` and `updated_at`. The API reference listed the order filters for this endpoint by mistake.

`CreditCardFilters` and `CreditCardSort` now accept `payment_method_id`, so you can list a customer's saved cards for one payment method.
