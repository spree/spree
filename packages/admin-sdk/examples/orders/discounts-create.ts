import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Line-item discount; omit line_item_id to distribute across the order.
const { data: discounts } = await client.orders.discounts.create('or_abc123', {
  label: 'Customer appeasement',
  value: 10,
  value_type: 'flat',
  line_item_id: 'item_abc123',
})

// endregion:example

export { discounts }
