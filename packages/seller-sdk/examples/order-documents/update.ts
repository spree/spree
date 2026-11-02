import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const document = await client.orders.documents.update('or_UkLWZg9DAJ', 'odoc_UkLWZg9DAJ', {
  customer_visible: true,
})

// endregion:example

export { document }
