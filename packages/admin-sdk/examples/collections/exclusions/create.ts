import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Keeps the product out, whatever the rules match or a merchant picked.
const exclusion = await client.collections.exclusions.create('coll_UkLWZg9DAJ', {
  product_id: 'prod_UkLWZg9DAJ',
})

// endregion:example

export { exclusion }
