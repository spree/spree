---
"@spree/sdk": patch
---

Switch API `sort` parameter to JSON:API standard `-field` notation. Use `-price` for descending and `price` for ascending instead of `price desc` / `price asc`. The `sort` parameter is now supported on all list endpoints (products, taxons, orders, taxonomies, etc.).
