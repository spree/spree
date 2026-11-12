import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const order = await client.orders.notes.update('or_UkLWZg9DAJ', {
  internal_note: '<p>Packed with the fragile insert.</p>',
})

// endregion:example

export { order }
