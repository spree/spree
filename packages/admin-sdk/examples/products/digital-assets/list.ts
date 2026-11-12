import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: digitalAssets } = await client.products.digitalAssets.list('prod_86Rf07xd4z')

// endregion:example

export { digitalAssets }
