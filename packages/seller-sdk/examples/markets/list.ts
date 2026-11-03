import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: markets } = await client.markets.list()

await client.products.update('prod_86Rf07xd4z', {
  market_availability: 'all_except',
  market_ids: [markets[0].id],
})

// endregion:example

export { markets }
