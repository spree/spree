import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: publications } = await client.categories.publications.list('ctg_UkLWZg9DAJ')

// endregion:example

export { publications }
