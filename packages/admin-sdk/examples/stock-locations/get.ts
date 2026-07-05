import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const stockLocation = await client.stockLocations.get('sloc_UkLWZg9DAJ')
// endregion:example

export { stockLocation }
