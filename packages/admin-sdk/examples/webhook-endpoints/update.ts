import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const endpoint = await client.webhookEndpoints.update('whe_xxx', {
  name: 'Order pipeline (v2)',
  subscriptions: ['order.completed', 'order.canceled', 'order.paid'],
})

// endregion:example

export { endpoint }
