---
"@spree/admin-sdk": patch
---

Added `client.products.activate`, `archive` and `draft`, which move one product to that status through its workflow, so the status event fires. Unlike `bulkStatusUpdate`, they refuse a product awaiting review.
