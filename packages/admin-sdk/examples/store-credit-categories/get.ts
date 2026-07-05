import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const category = await client.storeCreditCategories.get('sccat_UkLWZg9DAJ')
// endregion:example

export { category }
