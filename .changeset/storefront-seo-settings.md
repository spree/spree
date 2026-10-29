---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Added localized storefront SEO settings. Merchants edit the store's SEO title and meta description on Store Settings and translate them for each supported language. The Store SDK reads them with `client.store.get()`, and the Admin SDK reaches the store's translations with `client.store.translations.get()`.
