import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const address = await client.customer.addresses.update('addr_abc123', {
  city: 'Los Angeles',
}, {
  token: '<token>',
})
// endregion:example

export { address }
