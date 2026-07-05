import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
await client.carts.delete('cart_abc123', {
  token: '<token>',
})
// endregion:example
