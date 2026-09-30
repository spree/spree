---
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/sdk": patch
---

Added runtime Zod schemas to the Admin and Seller SDKs, exported from `@spree/admin-sdk/zod` and `@spree/seller-sdk/zod`, matching what `@spree/sdk/zod` already offers for the Store API. Schemas for inline objects, unions and records are now precise instead of accepting any value, which also tightens a few Store SDK schemas (cart warnings, payment sources, product filters).
