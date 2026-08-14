import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: locations } = await client.companies.locations.list('comp_UkLWZg9DAJ')

// endregion:example

export { locations }
