import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const collection = await client.collections.update('coll_UkLWZg9DAJ', {
  name: 'Winter Sale',
})

// endregion:example

export { collection }
