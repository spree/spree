import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The catalog and the price list it charges through are written together, so
// standing up an agreement never means visiting the price-lists page.
const catalog = await client.catalogs.create({
  name: 'VIP Assortment',
  price_list: { price_adjustment_percentage: '-15.0' },
})

// endregion:example

export { catalog }
