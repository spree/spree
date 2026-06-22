---
"@spree/sdk": minor
---

Add `constructEvent` for one-call webhook verification + parsing, and a fully-typed `SpreeWebhookEvent` discriminated union.

`constructEvent(rawBody, headers, secret)` verifies the HMAC signature and returns the parsed event in a single step, throwing `WebhookVerificationError` on a bad/missing/stale signature or invalid JSON — so an unverified payload can't be used by mistake. It accepts both a plain headers object and a `Headers` instance. Narrowing on `event.name` types `event.data` to the matching Store API resource (e.g. `order.completed` → `Order`).

Both `constructEvent` and `SpreeWebhookEvent` take an optional `TExtra` type parameter to merge in events emitted by custom models or extensions, so they narrow with full types alongside the built-in events. Event names outside the catalog and `TExtra` (e.g. from a newer Spree than the installed SDK) still type-check with `data: unknown`. The existing `verifyWebhookSignature` and generic `WebhookEvent<T>` remain available.
