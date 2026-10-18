import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: media } = await client.products.media.list('prod_UkLWZg9DAJ')

// endregion:example

export { media }
