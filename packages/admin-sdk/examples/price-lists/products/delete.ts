import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { removed_count } = await client.priceLists.products.delete('pl_UkLWZg9DAJ', [
  'prod_86Rf07xd4z',
])

// endregion:example

export { removed_count }
