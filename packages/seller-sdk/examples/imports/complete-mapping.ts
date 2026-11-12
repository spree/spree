import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const productImport = await client.imports.completeMapping('imp_UkLWZg9DAJ', {
  mappings: [{ schema_field: 'name', file_column: 'Product name' }],
})

// endregion:example

export { productImport }
