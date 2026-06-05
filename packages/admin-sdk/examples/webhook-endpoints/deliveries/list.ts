import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const deliveries = await client.webhookEndpoints.deliveries.list('whe_xxx')

// endregion:example

export { deliveries }
