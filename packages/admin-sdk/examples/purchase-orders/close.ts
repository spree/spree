import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The supplier will not send the balance: keep what arrived, record why.
const purchaseOrder = await client.purchaseOrders.close('po_1234567890', {
  reason: 'Supplier out of stock',
})

// endregion:example

export { purchaseOrder }
