import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const order = await client.orders.get('or_abc123', {}, {
  token: '<token>',
})
// endregion:example

export { order }
