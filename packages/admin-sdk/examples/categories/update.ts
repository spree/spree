import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const category = await client.categories.update('ctg_UkLWZg9DAJ', {
  name: 'Apparel',
  meta_title: 'Apparel for every season',
})

// endregion:example

export { category }
