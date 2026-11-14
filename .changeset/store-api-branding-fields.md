---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
"@spree/dashboard-core": patch
---

`client.store.get()` now also returns the store's `meta_keywords`, `logo_url`, social accounts (`facebook`, `twitter`, `instagram`) and `customer_support_email`, so a storefront can read its logo and structured data from the Store API instead of environment variables. The Admin API accepts `meta_keywords`, `facebook`, `twitter` and `instagram` on store update, and Store settings in the dashboard gains the store logo, meta keywords and a Social media card.
