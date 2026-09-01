import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Takes it out of effect; its assignments, terms and prices survive.
const catalog = await client.catalogs.deactivate('cat_xxx')

// endregion:example

export { catalog }
