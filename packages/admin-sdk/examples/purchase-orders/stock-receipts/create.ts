import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// This delivery's counts, not running totals: 58 accepted, 2 refused as
// damaged. A second delivery adds to the first. Omit `items` to book in
// everything still outstanding, intact.
const stockReceipt = await client.purchaseOrders.stockReceipts.create('po_1234567890', {
  reference: 'DN-4471',
  items: [
    {
      id: 'poi_1234567890',
      quantity_accepted: 58,
      quantity_rejected: 2,
      rejection_reason: 'damaged',
    },
  ],
})

// endregion:example

export { stockReceipt }
