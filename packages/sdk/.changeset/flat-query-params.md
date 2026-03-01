---
"@spree/sdk": patch
---

Added flat query params for filtering and sorting. Instead of `{ 'q[name_cont]': 'shirt' }`, you can now write `{ name_cont: 'shirt', sort: 'price asc' }`. The SDK transforms these to Ransack format automatically. Old `q[...]` syntax still works for backward compatibility.
