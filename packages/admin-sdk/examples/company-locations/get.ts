import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const location = await client.companyLocations.get('cloc_UkLWZg9DAJ')

// endregion:example

export { location }
