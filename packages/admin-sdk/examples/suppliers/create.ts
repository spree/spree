import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const supplier = await client.suppliers.create({
  name: 'Acme Wholesale',
  contact_name: 'Dana Okafor',
  email: 'sales@acme.test',
  city: 'Brooklyn',
  country_code: 'US',
})

// endregion:example

export { supplier }
