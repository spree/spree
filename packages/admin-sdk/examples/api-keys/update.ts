import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Only `name` is editable — scopes and key_type are fixed at creation.
const key = await client.apiKeys.update('key_xxx', { name: 'CI key (renamed)' })

// endregion:example

export { key }
