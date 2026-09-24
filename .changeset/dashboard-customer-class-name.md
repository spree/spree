---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/admin-sdk": patch
---

The dashboard now refers to customers by their 6.0 class name, `Spree::Customer`, instead of the pre-6.0 `Spree::User`. This fixes the Customers list's Tags filter, which always showed "No results", along with customer permission checks and customer custom fields. `client.customFields('Spree::Customer', id)` is now supported; `'Spree::User'` keeps working until 6.1.
