---
"@spree/core": patch
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Fixed "crypto.randomUUID is not a function" when the dashboard is opened over plain HTTP at an address other than `localhost`, for example a server's IP address. Browsers only provide `crypto.randomUUID` on secure pages, and every request that saves data needs one, starting with the store setup page. `@spree/core` now exports a `randomUUID()` that falls back to `crypto.getRandomValues`, and the SDKs and dashboards use it.
