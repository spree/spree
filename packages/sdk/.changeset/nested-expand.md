---
"@spree/sdk": patch
---

Added support for nested expand with dot notation. Pass `expand: ['variants.images']` to expand associations up to 4 levels deep. No SDK code changes required — this is a backend feature that works with the existing SDK.
