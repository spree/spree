import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { added_count } = await client.catalogs.importProducts('cat_86Rf07xd4z')

// endregion:example

export { added_count }
