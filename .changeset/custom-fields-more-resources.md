---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard-ui": minor
"@spree/admin-sdk": minor
---

Added custom field editing to variants, option types, sellers, promotions, gift cards, store credits, stock transfers, purchase orders, companies, payment methods, delivery methods, tax rates, product types, media and store settings. Sheets show the custom fields card only once the store defines a field for that type. On the product page, variant and media custom fields save with the sheet's Done, and widgets in their `product.variant.form_fields` and `product.media.form_fields` slots can save on Done through `onSave`. `FormActions` and `useFormSubmitShortcut` accept `dirty` for unsaved changes held outside the form. `client.customFields(ownerType, ownerId)` accepts each of these types.
