import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Everything the store holds about the customer, to answer a GDPR access request:
const customerData = await client.customers.export('cus_UkLWZg9DAJ')

// endregion:example

export { customerData }
