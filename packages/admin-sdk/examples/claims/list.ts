import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: claims } = await client.claims.list({
  status_eq: 'open',
  sort: '-created_at',
})

// endregion:example

export { claims }
