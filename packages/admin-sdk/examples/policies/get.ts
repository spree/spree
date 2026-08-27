import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Addressable by slug as well as prefixed id.
const policy = await client.policies.get('returns-policy')

// endregion:example

export { policy }
