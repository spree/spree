---
"@spree/admin-sdk": minor
---

Expose the store-wide gated storefront defaults on the Store resource. `Store.preferred_storefront_access` (`public`, `prices_hidden`, or `login_required`) and `Store.preferred_guest_checkout` are now serialized, and `StoreUpdateParams` accepts both — letting apps read and configure the store-level fallback that channels inherit when they don't set their own posture.
