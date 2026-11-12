import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: categories } = await client.categories.list({
  name_cont: 'Shirts',
  limit: 25,
})

// endregion:example

export { categories }
