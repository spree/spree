---
"@spree/seller-sdk": patch
---

A retried request now waits for a `Retry-After` header given as an HTTP date (`Retry-After: Wed, 21 Oct 2026 07:28:00 GMT`). Before, the SDK read the date as no delay and retried at once. A header it cannot read falls back to the usual backoff.
