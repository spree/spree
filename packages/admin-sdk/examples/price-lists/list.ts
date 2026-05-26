import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: priceLists } = await client.priceLists.list()
// endregion:example

export { priceLists }
