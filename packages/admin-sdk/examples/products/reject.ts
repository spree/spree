import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The seller sees the reason, fixes the product and submits it again.
const product = await client.products.reject('prod_86Rf07xd4z', {
  reason: 'Photos are too dark',
})

// endregion:example

export { product }
