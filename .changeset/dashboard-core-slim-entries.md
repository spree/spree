---
"@spree/dashboard": patch
"@spree/dashboard-core": minor
---

`@spree/dashboard-core` now exposes `@spree/dashboard-core/client` (`adminClient`) and `@spree/dashboard-core/api-client` (`setApiClient`), so a small app that only needs the Admin API client and sign-in no longer bundles the whole framework through the package entry point. `StoreSetupFields` imports only the modules it uses, cutting a minimal app that mounts it from about 2.2 MB to 0.9 MB of JavaScript.
