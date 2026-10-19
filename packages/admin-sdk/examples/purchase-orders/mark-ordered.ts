import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Sends the order to the supplier: the lines freeze and the expected date starts counting.
const purchaseOrder = await client.purchaseOrders.markOrdered('po_1234567890')

// endregion:example

export { purchaseOrder }
