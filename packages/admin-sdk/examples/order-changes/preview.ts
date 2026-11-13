import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const preview = await client.orders.orderChanges.preview('or_UkLWZg9DAJ', {
  actions: [{ kind: 'update_item', line_item_id: 'li_UkLWZg9DAJ', quantity: 3 }],
})

// endregion:example

export { preview }
