import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const exchange = await client.orders.exchanges.receive('or_UkLWZg9DAJ', 'exch_UkLWZg9DAJ', {
  items: [{ exchange_line_item_id: 'eli_UkLWZg9DAJ', quantity: 1, resellable: true }],
})

// endregion:example

export { exchange }
