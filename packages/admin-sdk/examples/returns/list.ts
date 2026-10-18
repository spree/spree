import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: returns } = await client.returns.list({
  status_eq: 'requested',
  sort: '-created_at',
})

// endregion:example

export { returns }
