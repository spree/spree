---
"@spree/sdk": minor
---

Flatten client API — `createClient()` replaces `createSpreeClient()`, all store resources are now top-level (`client.products.list()` instead of `client.products.list()`). Generated types are re-exported with unprefixed names (`Product` instead of `StoreProduct`; prefixed names remain as aliases for backward compatibility). Shared HTTP client, retry logic, and param utilities extracted to internal `@spree/sdk-core` package.
