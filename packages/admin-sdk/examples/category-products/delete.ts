import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { removed_count } = await client.categories.products.delete('ctg_UkLWZg9DAJ', [
  'prod_UkLWZg9DAJ',
])

// endregion:example

export { removed_count }
