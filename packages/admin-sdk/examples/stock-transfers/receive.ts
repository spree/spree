import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Partial receipt is the normal case: ten left, eight arrived.
const stockTransfer = await client.stockTransfers.receive('st_1234567890', {
  items: [{ id: 'sti_1234567890', quantity_received: 8, discrepancy_reason: 'damaged_in_transit' }],
})

// endregion:example

export { stockTransfer }
