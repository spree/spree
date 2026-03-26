---
"@spree/sdk": minor
---

Replace `categories_id_eq` filter and `categories.products.list()` with `in_category` / `in_categories` scopes on the `/products` endpoint. Category filters now include descendant categories.
