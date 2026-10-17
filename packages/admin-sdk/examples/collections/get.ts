import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const collection = await client.collections.get('coll_UkLWZg9DAJ', {
  expand: ['rules'],
})

// endregion:example

export { collection }
