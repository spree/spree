import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Drafts only. Sending `items` replaces every line on the order.
const purchaseOrder = await client.purchaseOrders.update('po_1234567890', {
  expected_at: '2026-10-15',
  reference: 'ACME-88412',
  items: [{ variant_id: 'variant_1234567890', quantity_ordered: 120, unit_cost: '12.50' }],
})

// endregion:example

export { purchaseOrder }
