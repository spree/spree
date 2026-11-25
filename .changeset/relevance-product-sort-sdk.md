---
"@spree/sdk": patch
---

`products.list()` accepts `sort: 'relevance'`, which puts the best match for the search query first. `products.filters()` offers it in `sort_options` when the request has a search query and the search provider ranks results.
