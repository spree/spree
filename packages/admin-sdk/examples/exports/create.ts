import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const exp = await client.exports.create({
  type: 'products',
  search_params: { name_cont: 'shirt' },
})

// endregion:example

export { exp }
