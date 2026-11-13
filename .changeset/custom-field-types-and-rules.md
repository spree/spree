---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Custom fields gain `date`, `date_time` and `choice` types and validation rules (`required`, `min` / `max`, `choices`, `multiple`), read from `CustomFieldDefinition.validations` and written through `validations` on create and update. A definition's `field_type` and `resource_type` are fixed once created, so `CustomFieldDefinitionUpdateParams` no longer has them, and new definitions are hidden from the storefront unless `storefront_visible` is sent. The dashboard edits the rules, renders the new types with a date picker and a choice picker, marks required fields, and checks values before saving.
