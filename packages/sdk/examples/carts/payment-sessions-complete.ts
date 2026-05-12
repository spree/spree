import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const session = await client.carts.paymentSessions.complete('cart_abc123', 'ps_abc123', {
  session_result: 'success',
}, {
  token: '<token>',
})
// endregion:example

export { session }
