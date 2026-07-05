import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { price_count } = await client.prices.bulkUpsert({
  prices: [
    {
      variant_id: 'variant_xxx',
      currency: 'USD',
      price_list_id: 'pl_xxx',
      amount: '11.11',
    },
    {
      variant_id: 'variant_yyy',
      currency: 'USD',
      price_list_id: 'pl_xxx',
      amount: '22.22',
    },
  ],
})
// endregion:example

export { price_count }
