import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const productType = await client.productTypes.update('pt_UkLWZg9DAJ', {
  name: 'Premium T-Shirt',
})

// endregion:example

export { productType }
