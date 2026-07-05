import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const customer = await client.customer.get({
  token: '<token>',
})
// endregion:example

export { customer }
