import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const product = await client.products.get('prod_86Rf07xd4z', {
  expand: ['variants', 'option_types'],
})
// endregion:example

export { product }
