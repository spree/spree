import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: variants } = await client.products.variants.list('prod_86Rf07xd4z', {
  expand: ['prices', 'stock_items'],
})
// endregion:example

export { variants }
