import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const address = await client.companies.addresses.create('comp_UkLWZg9DAJ', {
  first_name: 'Jane',
  last_name: 'Doe',
  company: 'Acme Wholesale',
  label: 'Warehouse',
  address1: '350 Fifth Avenue',
  city: 'New York',
  postal_code: '10118',
  country_code: 'US',
  state_code: 'NY',
  phone: '+12125551234',
  default_shipping: true,
})

// endregion:example

export { address }
