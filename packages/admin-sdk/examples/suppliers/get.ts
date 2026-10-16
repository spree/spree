import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const supplier = await client.suppliers.get('sup_1234567890')

// endregion:example

export { supplier }
