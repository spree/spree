import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Only while no delivery has been booked against it.
const purchaseOrder = await client.purchaseOrders.markDraft('po_1234567890')

// endregion:example

export { purchaseOrder }
