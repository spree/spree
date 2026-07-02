import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const fulfillment = await client.orders.fulfillments.create('or_UkLWZg9DAJ', {
  stock_location_id: 'sloc_UkLWZg9DAJ',
  tracking: 'INPOST-12345',
  delivery_method_id: 'dm_UkLWZg9DAJ',
  status: 'shipped',
  items: [{ item_id: 'li_UkLWZg9DAJ', quantity: 1 }],
})

// endregion:example

export { fulfillment }
