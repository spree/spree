import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const definition = await client.customFieldDefinitions.update('cfd_UkLWZg9DAJ', {
  label: 'Country of Origin',
  storefront_visible: false,
})

// endregion:example

export { definition }
