import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const packageType = await client.packageTypes.get('pkgtype_UkLWZg9DAJ')

// endregion:example

export { packageType }
