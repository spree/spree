import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const addresses = await client.customer.addresses.list({}, {
  token: '<token>',
})
// endregion:example

export { addresses }
