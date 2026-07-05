import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const customField = await client.products.customFields.create('prod_UkLWZg9DAJ', {
  custom_field_definition_id: 'cfdef_AbC123XyZ',
  value: 'wool',
})
// endregion:example

export { customField }
