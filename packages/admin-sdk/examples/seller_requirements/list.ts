import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The checklist in the order sellers work through it. `required` items block
// approval; the rest are shown as recommended.
const { data: sellerRequirements } = await client.sellerRequirements.list({ page: 1, limit: 25 })

// endregion:example

export { sellerRequirements }
