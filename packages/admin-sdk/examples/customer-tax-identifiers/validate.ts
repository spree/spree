import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const registration = await client.customers.taxIdentifiers.validate(
  'cus_UkLWZg9DAJ',
  'txi_UkLWZg9DAJ',
)

// endregion:example

export { registration }
