import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const profile = await client.profile.update({
  name: 'Acme Outfitters',
  contact_email: 'hello@acme.example',
  legal_name: 'Acme Outfitters Ltd',
})

// endregion:example

export { profile }
