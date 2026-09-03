import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Puts the agreement into effect. Refused for a catalog nobody is assigned
// to, which would reach no buyer.
const catalog = await client.catalogs.activate('cat_xxx')

// endregion:example

export { catalog }
