import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const policy = await client.policies.create({
  name: 'Wholesale Policy',
  body: '<p>Trade orders ship within five working days.</p>',
})

// endregion:example

export { policy }
