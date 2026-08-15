import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const location = await client.companies.locations.create('comp_UkLWZg9DAJ', {
  name: 'Hamburg warehouse',
  billing_address: {
    first_name: 'Anna',
    last_name: 'Muller',
    address1: 'Hafenstr 1',
    city: 'Hamburg',
    postal_code: '20095',
    country_code: 'DE',
  },
})

// endregion:example

export { location }
