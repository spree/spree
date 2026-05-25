import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const priceList = await client.priceLists.update('pl_xxx', {
  name: 'Wholesale (Q3)',
})
// endregion:example

export { priceList }
