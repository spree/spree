---
"@spree/sdk": patch
---

Add `state_lock_version` support for optimistic order locking. All order-mutating SDK methods now accept an optional `state_lock_version` parameter. When provided and stale, the API returns a 409 Conflict response.
