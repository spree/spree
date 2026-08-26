import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const catalog = await client.catalogs.create({
  name: 'VIP Assortment',
  price_list_id: 'pl_86Rf07xd4z',
})

// endregion:example

export { catalog }
