---
"@spree/sdk": patch
---

Removed `store.store` resource from the SDK. Store branding should be configured as developer config (env vars) rather than fetched from the API.
