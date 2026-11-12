import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Omit `items` to receive everything as requested and resellable.
const orderReturn = await client.orders.returns.receive('or_UkLWZg9DAJ', 'ret_UkLWZg9DAJ', {
  items: [{ return_line_item_id: 'rli_UkLWZg9DAJ', quantity: 1, resellable: false }],
})

// endregion:example

export { orderReturn }
