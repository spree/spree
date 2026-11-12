import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: digitalLinks } = await client.digitalLinks.list({
  sort: '-created_at',
})

// endregion:example

export { digitalLinks }
