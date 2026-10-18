import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: imports } = await client.imports.list({
  status_eq: 'failed',
  sort: '-created_at',
})

// endregion:example

export { imports }
