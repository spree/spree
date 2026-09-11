import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Every delivery the destination counted in.
const { data: stockReceipts } = await client.stockTransfers.stockReceipts.list('st_1234567890', {
  expand: ['items'],
})

// endregion:example

export { stockReceipts }
