import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const customer = await client.customer.update({
  first_name: 'John',
  last_name: 'Doe',
  metadata: { preferred_contact: 'email' },
}, {
  token: '<token>',
})
// endregion:example

export { customer }
