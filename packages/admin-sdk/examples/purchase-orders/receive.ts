import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `quantity_received` is the running total for the line, so a second delivery
// tops it up rather than starting over. Omit `items` to receive it all.
const purchaseOrder = await client.purchaseOrders.receive('po_1234567890', {
  items: [{ id: 'poi_1234567890', quantity_received: 60 }],
})

// endregion:example

export { purchaseOrder }
