import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const { data: invoices } = await client.orders.invoices.list(
  'or_abc123',
  {},
  {
    token: '<token>',
  },
)

// endregion:example

export { invoices }
