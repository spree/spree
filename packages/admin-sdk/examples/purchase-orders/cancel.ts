import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const purchaseOrder = await client.purchaseOrders.cancel('po_1234567890', {
  reason: 'Supplier discontinued the line',
})

// endregion:example

export { purchaseOrder }
