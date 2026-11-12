import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderReturn = await client.orders.returns.create('or_UkLWZg9DAJ', {
  reason_id: 'rar_UkLWZg9DAJ',
  items: [{ fulfillment_item_id: 'fi_UkLWZg9DAJ', quantity: 1 }],
})

// endregion:example

export { orderReturn }
