import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const taxIdentifier = await client.taxIdentifiers.create({
  kind: 'eu_vat',
  value: 'DE123456789',
})

// endregion:example

export { taxIdentifier }
