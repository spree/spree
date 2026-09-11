import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Every delivery booked against the order, with its lines.
const { data: stockReceipts } = await client.purchaseOrders.stockReceipts.list('po_1234567890', {
  expand: ['items'],
})

// endregion:example

export { stockReceipts }
