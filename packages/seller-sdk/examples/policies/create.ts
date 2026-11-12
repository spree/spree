import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const policy = await client.policies.create({
  name: 'Returns Policy',
  body: '<p>Return anything unopened within 30 days.</p>',
})

// endregion:example

export { policy }
