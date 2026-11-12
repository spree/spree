import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const supplier = await client.suppliers.update('sup_1234567890', {
  contact_name: 'Jordan Lee',
  email: 'orders@acme-supply.com',
  phone: '+1 555 0100',
})

// endregion:example

export { supplier }
