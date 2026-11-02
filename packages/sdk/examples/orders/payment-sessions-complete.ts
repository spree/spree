import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const session = await client.orders.paymentSessions.complete(
  'or_abc123',
  'ps_abc123',
  {
    session_result: 'success',
  },
  {
    token: '<token>',
  },
)

// endregion:example

export { session }
