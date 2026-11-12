import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: addresses } = await client.companies.addresses.list('comp_UkLWZg9DAJ')

// endregion:example

export { addresses }
