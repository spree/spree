import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const productType = await client.productTypes.get('pt_UkLWZg9DAJ')

// endregion:example

export { productType }
