---
"@spree/sdk": patch
---

Added `checkout_steps` field to `StoreOrder` type. Returns an array of applicable checkout step names for the order (e.g., `["address", "delivery", "payment", "complete"]`). Steps are dynamic per order — digital-only orders may skip `delivery`, free orders may skip `payment`. Use alongside `state` to build dynamic checkout step indicators.
