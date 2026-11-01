import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.orders.documents.delete('or_UkLWZg9DAJ', 'odoc_UkLWZg9DAJ')

// endregion:example
