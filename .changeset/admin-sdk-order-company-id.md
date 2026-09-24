---
"@spree/admin-sdk": patch
---

`orders.create` and `orders.update` params now include `company_id`, which the Admin API already accepted. Sending it makes a draft a company purchase; `null` on update clears it.
