import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const packageType = await client.packageTypes.update('pkgtype_UkLWZg9DAJ', {
  max_weight: 15,
})

// endregion:example

export { packageType }
