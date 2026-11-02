import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const session = await client.orders.paymentSessions.update(
  'or_abc123',
  'ps_abc123',
  {
    amount: '50.00',
  },
  {
    token: '<token>',
  },
)

// endregion:example

export { session }
