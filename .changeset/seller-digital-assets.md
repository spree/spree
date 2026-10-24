---
"@spree/seller-sdk": minor
"@spree/seller-dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard": patch
---

Sellers can manage the downloadable files on their own digital products. The Seller SDK adds `products.digitalAssets` (`list`, `get`, `create`, `update`, `delete`), and the seller panel's product page shows the same Digital files card as the dashboard: upload, replace and delete files, and set per-file download limits. A file the marketplace delivers through its own provider is listed but cannot be replaced by the seller. The card now lives in `@spree/dashboard-core` as `DigitalAssetsCard`, and a panel enables it by registering `digitalAssets` on its API client.
