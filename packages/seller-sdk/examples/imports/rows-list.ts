import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const { data: rows } = await client.imports.rows.list('imp_UkLWZg9DAJ', {
  status_eq: 'failed',
})

// endregion:example

export { rows }
