import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const digitalAsset = await client.products.digitalAssets.get('prod_UkLWZg9DAJ', 'dig_k5nR8xLqPz')

// endregion:example

export { digitalAsset }
