import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: storeCredits, meta } = await client.storeCredits.list({
  page: 1,
  limit: 25,
  outstanding: true,
  expand: ['customer', 'created_by'],
})

// What the store still owes, one row per currency, over the same filter.
const outstanding = meta.totals

// endregion:example

export { outstanding, storeCredits }
