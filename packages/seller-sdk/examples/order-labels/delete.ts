import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
await client.orders.fulfillments.labels.delete('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', 'lbl_UkLWZg9DAJ')
// endregion:example
