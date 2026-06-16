---
"@spree/admin-sdk": patch
---

API key scopes are now immutable after creation. `apiKeys.update()` accepts only `name` (`ApiKeyUpdateParams` no longer includes `scopes`). Added `apiKeys.current()` to describe the authenticating key, including its live scopes.
