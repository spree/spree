---
"@spree/seller-sdk": minor
---

Added `products.media.delete` for removing a file from a product's gallery. A product update never removes a file it was not sent, so this is the only way to take one off; the `media` description on product create and update now says so.
