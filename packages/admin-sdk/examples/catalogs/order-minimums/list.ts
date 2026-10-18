import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: orderMinimums } = await client.catalogs.orderMinimums.list('cat_UkLWZg9DAJ')

// endregion:example

export { orderMinimums }
