import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const packageType = await client.packageTypes.get('pkgtype_123')

// endregion:example

export { packageType }
