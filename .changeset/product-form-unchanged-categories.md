---
"@spree/dashboard-core": patch
"@spree/dashboard": patch
---

Saving a product no longer removes categories, collections or tags added after the page was opened, from another tab, a bulk action or an import. The product page now sends the product's categories, collections and tags only when you changed them.
