import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.fulfillments.update('cart_abc123', 'ful_abc123', {
  selected_delivery_rate_id: 'dr_abc123',
}, {
  token: '<token>',
})
// endregion:example

export { cart }
