import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.rotateToken('cart_abc123', {
  spreeToken: '<cart-token>',
})

// cart.token is the new token; the old one no longer opens the cart

// endregion:example

export { cart }
