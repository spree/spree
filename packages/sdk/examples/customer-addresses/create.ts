import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const address = await client.customer.addresses.create({
  first_name: 'John',
  last_name: 'Doe',
  address1: '123 Main St',
  city: 'New York',
  postal_code: '10001',
  country_iso: 'US',
  state_abbr: 'NY',
  phone: '+1 555 123 4567',
}, {
  token: '<token>',
})
// endregion:example

export { address }
