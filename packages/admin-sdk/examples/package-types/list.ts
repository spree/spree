import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: packageTypes } = await client.packageTypes.list()

// endregion:example

export { packageTypes }
