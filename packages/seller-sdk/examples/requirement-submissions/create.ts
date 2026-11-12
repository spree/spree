import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const submission = await client.requirementSubmissions.create('selreq_xxx', {
  note: 'Confirmed.',
})

// endregion:example

export { submission }
