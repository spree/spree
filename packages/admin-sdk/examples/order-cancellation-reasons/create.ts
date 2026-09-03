import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const reason = await client.orderCancellationReasons.create({
  name: 'Out of stock',
})

// endregion:example

export { reason }
