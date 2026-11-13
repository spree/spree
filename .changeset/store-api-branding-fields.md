---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
---

`client.store.get()` now also returns the store's `meta_keywords`, `logo_url`, social accounts (`facebook`, `twitter`, `instagram`), `customer_support_email` and `mail_from_address`, so a storefront can read its logo, structured data and email sender from the Store API instead of environment variables. The Admin API accepts `meta_keywords`, `facebook`, `twitter` and `instagram` on store update, and Store settings in the dashboard gains the store logo, meta keywords and a Social media card.
