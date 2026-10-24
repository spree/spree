---
"@spree/seller-sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard": minor
---

Sellers can manage the downloadable files on their own digital products. The Seller SDK adds `products.digitalAssets` (`list`, `get`, `create`, `update`, `delete`), and the seller panel's product page shows the same Digital files card as the dashboard: upload, replace and delete files, and set per-file download limits. A file the marketplace delivers through its own provider is listed but cannot be replaced by the seller. The card now lives in `@spree/dashboard-core` as `DigitalAssetsCard`, and a panel enables it by registering `digitalAssets` on its API client; `readOnly` shows the files without any way to change them and `accept` narrows the file picker.

Seller uploads are a marketplace decision: three store settings, edited on the dashboard's Marketplace settings page, say whether sellers may upload at all (off by default), which content types their files may have, and whether a file added to or replaced on an approved product sends it back to review. The seller `/me` response carries them under `store`, and the Admin SDK's `Store` type gains the three fields.
