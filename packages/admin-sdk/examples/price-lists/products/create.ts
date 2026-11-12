import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { added_count } = await client.priceLists.products.create('pl_UkLWZg9DAJ', [
  'prod_86Rf07xd4z',
  'prod_9XbR2kQwLm',
])

// endregion:example

export { added_count }
