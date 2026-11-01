import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const offer = await client.variants.create('prod_UkLWZg9DAJ', {
  sku: 'MUG-USED-01',
  options: [{ name: 'condition', value: 'used' }],
  prices: [{ currency: 'USD', amount: '18.00' }],
  stock_levels: [{ stock_location_id: 'sloc_UkLWZg9DAJ', count_on_hand: 4 }],
})

// endregion:example

export { offer }
