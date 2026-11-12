import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const productImport = await client.imports.create({
  type: 'products',
  attachment_signed_id: 'eyJfcmFpbHMiOnsiZGF0YSI6MTIzLCJwdXIiOiJibG9iX2lkIn19--4b9d',
})

// endregion:example

export { productImport }
