import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const payment = await client.carts.payments.create('cart_abc123', {
  payment_method_id: 'pm_abc123',
}, {
  token: '<token>',
})
// endregion:example

export { payment }
