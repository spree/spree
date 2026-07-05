import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: stockLocations } = await client.stockLocations.list()
// endregion:example

export { stockLocations }
