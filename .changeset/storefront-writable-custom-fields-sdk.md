---
"@spree/sdk": minor
---

Shoppers can fill in custom fields. `client.customFieldDefinitions.list({ resource_type_eq: 'order' })` lists the fields a storefront asks at checkout (or `'customer'` for registration and the account), with their type, label and rules. Write values by `full_key` in `custom_fields` on `CreateCartParams`, `UpdateCartParams`, `RegisterParams` and `UpdateCustomerParams`, and read them back with `expand: ['custom_fields']`, now also on the cart. A required order field the cart lacks is listed in `requirements` with the code `custom_field_required`.
