import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.storeCredits.remove('cart_abc123', {
  token: '<token>',
})
// endregion:example

export { cart }
