import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const key = await client.apiKeys.revoke('key_xxx')
// endregion:example

export { key }
