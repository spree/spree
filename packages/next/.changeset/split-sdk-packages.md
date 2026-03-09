---
"@spree/next": minor
---

Update to use flattened `@spree/sdk` client API — `createClient()` replaces `createSpreeClient()`, `client.products.list()` replaces `client.products.list()`. All re-exported types use unprefixed names (`Product` instead of `StoreProduct`).
