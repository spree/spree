---
"@spree/sdk": patch
---

Webhook types include `store.updated`, which Spree sends each time the store's settings are saved in Spree Admin, including a translation or the logo. Its `data` is typed as `Store`, the shape `store.get()` returns, so a storefront can expire its cached store data when it arrives.
