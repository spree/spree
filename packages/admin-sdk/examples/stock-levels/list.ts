import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// One row per variant per location: on hand, committed, reserved, available
// and incoming, with the variant and location named flat on the row.
const { data: stockLevels } = await client.stockLevels.list({
  q: { stock_location_id_eq: 'sloc_xxx' },
})

// endregion:example

export { stockLevels }
