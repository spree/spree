import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const taxIdentifier = await client.taxIdentifiers.update('txi_xxx', {
  value: 'DE987654321',
})

// endregion:example

export { taxIdentifier }
