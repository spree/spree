import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const customField = await client.products.customFields.get('prod_UkLWZg9DAJ', 'cf_AbC123XyZ')

// endregion:example

export { customField }
