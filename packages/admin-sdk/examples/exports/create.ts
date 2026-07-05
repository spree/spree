import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const exp = await client.exports.create({
  type: 'Spree::Exports::Products',
  search_params: { name_cont: 'shirt' }
})
// endregion:example

export { exp }
