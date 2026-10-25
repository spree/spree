import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const claim = await client.orders.claims.create('or_UkLWZg9DAJ', {
  items: [{ line_item_id: 'li_UkLWZg9DAJ', quantity: 1, description: 'Arrived damaged' }],
  reason_id: 'clr_UkLWZg9DAJ',
})

// endregion:example

export { claim }
