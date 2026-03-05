---
"@spree/sdk": patch
---

Add `idempotencyKey` option to `RequestOptions` and auto-generate idempotency keys for all mutating requests (POST, PUT, PATCH, DELETE) when retries are enabled. This enables safe automatic retries on 5xx errors and network failures for all requests, matching Stripe SDK behavior. User-supplied keys take precedence over auto-generated ones.
