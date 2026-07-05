import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const store = await client.store.update({
  name: 'My Store'
})
// endregion:example

export { store }
