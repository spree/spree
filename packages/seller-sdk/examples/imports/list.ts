import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: imports } = await client.imports.list({
  status_eq: 'completed',
  sort: '-created_at',
})

// endregion:example

export { imports }
