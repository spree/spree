import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Omit `items` to receive every unit still to come as resellable.
const exchange = await client.orders.exchanges.receive('or_UkLWZg9DAJ', 'exch_UkLWZg9DAJ', {
  items: [{ exchange_line_item_id: 'eli_UkLWZg9DAJ', quantity: 1, resellable: false }],
})

// endregion:example

export { exchange }
