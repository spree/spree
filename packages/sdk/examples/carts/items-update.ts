import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.items.update('cart_abc123', 'li_abc123', {
  quantity: 5,
}, {
  token: '<token>',
})
// endregion:example

export { cart }
