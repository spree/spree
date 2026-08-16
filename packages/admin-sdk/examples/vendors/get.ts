import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const vendor = await client.vendors.get('ven_UkLWZg9DAJ')

// endregion:example

export { vendor }
