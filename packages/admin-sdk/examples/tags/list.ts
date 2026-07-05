import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: tags } = await client.tags.list({
  taggable_type: 'Spree::User',
  q: 'vip',
})
// endregion:example

export { tags }
