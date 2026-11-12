import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const exchange = await client.orders.exchanges.create('or_UkLWZg9DAJ', {
  reason_id: 'rar_UkLWZg9DAJ',
  stock_location_id: 'sloc_UkLWZg9DAJ',
  items: [
    { fulfillment_item_id: 'fi_UkLWZg9DAJ', new_variant_id: 'variant_k5nR8xLq', quantity: 1 },
  ],
})

// endregion:example

export { exchange }
