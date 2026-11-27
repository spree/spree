import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Omit `items` to receive every unit still to come as resellable. Name a line
// twice to receive part of it as resellable and part not.
const orderReturn = await client.orders.returns.receive('or_UkLWZg9DAJ', 'ret_UkLWZg9DAJ', {
  items: [
    { return_line_item_id: 'rli_UkLWZg9DAJ', quantity: 2, resellable: true },
    { return_line_item_id: 'rli_UkLWZg9DAJ', quantity: 1, resellable: false },
  ],
})

// endregion:example

export { orderReturn }
