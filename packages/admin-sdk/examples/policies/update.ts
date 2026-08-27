import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const policy = await client.policies.update('returns-policy', {
  body: '<p>Return anything unopened within 60 days.</p>',
})

// endregion:example

export { policy }
