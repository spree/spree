import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const category = await client.categories.get('ctg_UkLWZg9DAJ', {
  expand: ['children', 'ancestors'],
})

// endregion:example

export { category }
