import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.catalogs.orderMinimums.delete('cat_UkLWZg9DAJ', 'com_k5nR8xLqPz')

// endregion:example
