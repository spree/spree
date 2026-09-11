import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const purchaseOrder = await client.purchaseOrders.create({
  supplier_id: 'sup_1234567890',
  destination_location_id: 'sloc_1234567890',
  expected_at: '2026-10-01',
  items: [{ variant_id: 'variant_1234567890', quantity_ordered: 100, unit_cost: '12.50' }],
})

// endregion:example

export { purchaseOrder }
