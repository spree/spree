import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: exclusions } = await client.collections.exclusions.list('coll_UkLWZg9DAJ', {
  expand: ['product'],
})

// endregion:example

export { exclusions }
