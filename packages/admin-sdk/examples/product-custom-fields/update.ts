import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const customField = await client.products.customFields.update('prod_UkLWZg9DAJ', 'cf_AbC123XyZ', {
  value: 'cotton',
})

// endregion:example

export { customField }
