import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const endpoint = await client.webhookEndpoints.create({
  name: 'Order pipeline',
  url: 'https://example.com/webhooks/orders',
  active: true,
  subscriptions: ['order.completed', 'order.canceled'],
})

// The plaintext `secret_key` is returned exactly once on create — persist it
// immediately so you can verify incoming webhook signatures. Subsequent reads
// will return `null`.
const signingSecret = endpoint.secret_key

// endregion:example

export { endpoint, signingSecret }
