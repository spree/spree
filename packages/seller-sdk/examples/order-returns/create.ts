import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const orderReturn = await client.orders.returns.create('or_UkLWZg9DAJ', {
  items: [{ fulfillment_item_id: 'fi_UkLWZg9DAJ', quantity: 1 }],
  reason_id: 'rar_UkLWZg9DAJ',
})

// endregion:example

export { orderReturn }
