import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const orderChange = await client.orders.orderChanges.create('or_UkLWZg9DAJ', {
  confirm: true,
  actions: [
    { kind: 'update_item', line_item_id: 'li_UkLWZg9DAJ', quantity: 2 },
    { kind: 'add_item', variant_id: 'variant_UkLWZg9DAJ', quantity: 1 },
  ],
})

// endregion:example

export { orderChange }
