import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const key = await client.apiKeys.create({
  name: 'Backend integration',
  key_type: 'secret',
  scopes: ['read_orders', 'write_orders']
})
// `key.plaintext_token` is available only on this response.
// endregion:example

export { key }
