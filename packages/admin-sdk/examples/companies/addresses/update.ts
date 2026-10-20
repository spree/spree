import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const address = await client.companies.addresses.update('comp_UkLWZg9DAJ', 'addr_k5nR8xLqPz', {
  label: 'Northern Warehouse',
  default_billing: true,
})

// endregion:example

export { address }
