import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.collections.exclusions.delete('coll_UkLWZg9DAJ', 'cexcl_UkLWZg9DAJ')

// endregion:example
