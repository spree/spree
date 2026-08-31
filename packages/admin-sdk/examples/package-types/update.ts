import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const carton = await client.packageTypes.update('pkgtype_123', {
  max_weight: 25,
})

// endregion:example

export { carton }
