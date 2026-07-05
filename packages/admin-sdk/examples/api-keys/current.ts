import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Describes the key you authenticated with, including its live scopes.
const key = await client.apiKeys.current()

// endregion:example

export { key }
