import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: digitalAssets } = await client.products.digitalAssets.list('prod_UkLWZg9DAJ')

// endregion:example

export { digitalAssets }
