---
"@spree/admin-sdk": major
"@spree/dashboard": patch
---

Store credits no longer carry a category. `client.storeCreditCategories` and the `StoreCreditCategory` type are removed, `category_id` is no longer accepted or returned on customer store credits, and the dashboard's issue/edit store credit dialogs drop the category picker — the memo is the place to record why a credit was issued.
