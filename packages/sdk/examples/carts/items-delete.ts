import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.items.delete('cart_abc123', 'li_abc123', {
  token: '<token>',
})
// endregion:example

export { cart }
