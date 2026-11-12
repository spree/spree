import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Every variant in the store, across all products.
const { data: variants } = await client.variants.list({
  sku_cont: 'TSHIRT',
  limit: 25,
})

// endregion:example

export { variants }
