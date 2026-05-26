import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const priceList = await client.priceLists.activate('pl_xxx')
// endregion:example

export { priceList }
