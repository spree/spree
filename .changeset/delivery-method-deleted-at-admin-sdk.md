---
"@spree/admin-sdk": patch
---

`DeliveryMethod.deleted_at` is now typed `string | null`. The Admin API has always returned `null` for a delivery method that is not deleted; the type said it was always a string.
