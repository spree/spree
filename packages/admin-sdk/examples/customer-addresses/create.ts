import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const address = await client.customers.addresses.create('cus_UkLWZg9DAJ', {
  first_name: 'Jane',
  last_name: 'Doe',
  address1: '350 Fifth Avenue',
  city: 'New York',
  postal_code: '10118',
  country_iso: 'US',
  state_abbr: 'NY',
  phone: '+1 212 555 1234',
  label: 'Office',
  is_default_shipping: true,
})
// endregion:example

export { address }
