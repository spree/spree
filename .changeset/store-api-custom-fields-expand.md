---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
---

Added an optional `custom_fields` property to every record type that can carry custom fields, such as sellers, option types, media, orders, line items, addresses and customers. Request it with `expand: ['custom_fields']`. The Store API returns only fields marked storefront visible, and the Admin API returns every field.
