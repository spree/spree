import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.products.customFields.delete('prod_UkLWZg9DAJ', 'cf_AbC123XyZ')
// endregion:example
