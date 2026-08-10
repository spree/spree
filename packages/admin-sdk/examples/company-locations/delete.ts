import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.companyLocations.delete('cloc_UkLWZg9DAJ')
// endregion:example
