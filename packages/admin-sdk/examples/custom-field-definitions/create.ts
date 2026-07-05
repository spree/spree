import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const definition = await client.customFieldDefinitions.create({
  namespace: 'specs',
  key: 'origin',
  label: 'Country of Origin',
  field_type: 'short_text',
  resource_type: 'Spree::Product',
  storefront_visible: true,
})
// endregion:example

export { definition }
