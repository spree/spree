import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const category = await client.categories.create({
  name: 'Shirts',
  parent_id: 'ctg_UkLWZg9DAJ',
  description: '<p>Casual and dress shirts.</p>',
})

// endregion:example

export { category }
