import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.giftCards.apply('cart_abc123', 'GC-ABCD-1234', {
  token: '<token>',
})
// endregion:example

export { cart }
