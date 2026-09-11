import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Partial receipt is the normal case: ten left, eight arrived intact and two
// crushed. Refused units are recorded, never stocked.
const stockReceipt = await client.stockTransfers.stockReceipts.create('st_1234567890', {
  items: [
    {
      id: 'sti_1234567890',
      quantity_accepted: 8,
      quantity_rejected: 2,
      rejection_reason: 'damaged',
    },
  ],
})

// endregion:example

export { stockReceipt }
