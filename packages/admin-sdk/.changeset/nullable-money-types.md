---
"@spree/admin-sdk": minor
---

Regenerated types: money fields on Order, LineItem, Payment, Fulfillment, GiftCard, and Discount are now typed `string | null`, matching the serializer schema shared with the Store API (the Admin API itself always returns amounts — only gated storefront guests receive `null`). Also fixes `created_at`/`updated_at` on Country, State, and other resources previously typed `unknown` to `string`.
