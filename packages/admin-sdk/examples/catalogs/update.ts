import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const catalog = await client.catalogs.update('cat_UkLWZg9DAJ', {
  name: 'Wholesale Plus',
  minimum_order_quantity: 10,
  order_multiple: 5,
})

// endregion:example

export { catalog }
