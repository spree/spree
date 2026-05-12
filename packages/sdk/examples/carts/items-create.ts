import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.items.create('cart_abc123', {
  variant_id: 'variant_abc123',
  quantity: 2,
}, {
  token: '<token>',
})
// endregion:example

export { cart }
