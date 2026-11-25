---
"@spree/sdk": patch
"@spree/admin-sdk": patch
---

Product lists accept `sort: 'relevance'`, which puts the best match for the search query first. The product filters response offers it in `sort_options` when the request has a search query and the search provider ranks results.
