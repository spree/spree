import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.discountCodes.apply('cart_abc123', 'SAVE10', {
  token: '<token>',
})
// endregion:example

export { cart }
