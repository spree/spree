---
"@spree/admin-sdk": minor
---

Support channel binding on publishable API keys. `apiKeys.create()` accepts an optional `channel_id`, and `ApiKey` now carries `channel_id`. A bound key always resolves its channel server-side and rejects requests naming a different one; the binding is create-only and immutable. Omit `channel_id` for a store-wide key.
