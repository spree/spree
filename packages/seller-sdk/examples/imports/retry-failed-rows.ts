import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const productImport = await client.imports.retryFailedRows('imp_UkLWZg9DAJ')

// endregion:example

export { productImport }
