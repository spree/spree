import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const stockLocation = await client.stockLocations.update('sloc_UkLWZg9DAJ', {
  returns_enabled: true,
  phone: '+1 718 555 0100',
})

// endregion:example

export { stockLocation }
