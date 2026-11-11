import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const document = await client.orders.documents.update('or_UkLWZg9DAJ', 'odoc_UkLWZg9DAJ', {
  customer_visible: true,
})

// endregion:example

export { document }
