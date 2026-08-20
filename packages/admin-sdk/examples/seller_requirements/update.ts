import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Asks for three products instead of one. Sellers who already met the old
// number see this return to their checklist.
const sellerRequirement = await client.sellerRequirements.update('selreq_a1b2c3', {
  preferences: { minimum_count: 3 },
})

// endregion:example

export { sellerRequirement }
