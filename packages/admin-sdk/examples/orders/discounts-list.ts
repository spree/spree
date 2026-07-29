import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: discounts } = await client.orders.discounts.list('or_abc123')

// endregion:example

export { discounts }
