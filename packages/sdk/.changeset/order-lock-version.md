---
"@spree/sdk": patch
---

Add `state_lock_version` to `StoreOrder` and `AdminOrder` response types. The API now returns a `state_lock_version` field on order responses for tracking order mutation versions.
