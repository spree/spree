import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Irreversible: personal data is erased, orders and payments are kept.
const customer = await client.customers.anonymize('cus_UkLWZg9DAJ')

// endregion:example

export { customer }
