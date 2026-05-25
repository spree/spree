import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: prices } = await client.prices.list({
  price_list_id_eq: 'pl_xxx',
  currency_eq: 'USD',
  expand: ['variant'],
})
// endregion:example

export { prices }
