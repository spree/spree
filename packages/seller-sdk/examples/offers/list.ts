import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: offers, meta } = await client.variants.list({
  sort: '-created_at',
  limit: 25,
})

// endregion:example

export { meta, offers }
