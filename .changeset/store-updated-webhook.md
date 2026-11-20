---
"@spree/sdk": patch
"@spree/dashboard": patch
---

Webhook types include `store.updated`, which Spree sends when the store's settings change in Spree Admin, including a translation or the logo. Its `data` is typed as `Store`, the shape `store.get()` returns, so a storefront can expire its cached store data when it arrives. The webhook endpoint form lists the event under a new Store group.
