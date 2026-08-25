import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { stock_level_count } = await client.stockLevels.bulkUpsert({
  stock_levels: [
    {
      variant_id: 'variant_xxx',
      stock_location_id: 'sloc_xxx',
      count_on_hand: 42,
    },
  ],
})

// endregion:example

export { stock_level_count }
