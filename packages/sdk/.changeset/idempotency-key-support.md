---
"@spree/sdk": patch
---

Add `idempotencyKey` option to `RequestOptions` for safe retries of mutating requests. When an idempotency key is provided, the SDK sets the `Idempotency-Key` header and enables automatic retries on 5xx errors and network failures (same retry behavior as GET requests).
