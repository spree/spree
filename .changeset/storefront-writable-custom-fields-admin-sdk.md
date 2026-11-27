---
"@spree/admin-sdk": minor
---

`CustomFieldDefinition` gains `storefront_writable` (and `full_key`), so shoppers can fill in an order field at checkout or a customer field at registration and from their account. It is accepted on create and update for order and customer fields that are also `storefront_visible`. The admin cart serializer now offers `expand: ['custom_fields']`.
