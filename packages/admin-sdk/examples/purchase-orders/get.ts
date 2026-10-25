import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const purchaseOrder = await client.purchaseOrders.get('po_1234567890', {
  expand: ['items', 'supplier'],
})

// endregion:example

export { purchaseOrder }
